begin

  @task = nil
  @service = nil

  # Simple logging method
  def log(level, msg)
    $evm.log(level, msg)
  end

  # Error logging convenience
  def log_err(err)
    log(:error, "#{err.class} #{err}")
    log(:error, "#{err.backtrace.join("\n")}")
  end

  # standard dump of $evm.root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def get_aws_object(ext_mgt_system, type="EC2")
    require 'aws-sdk'
    AWS.config(
      :access_key_id => ext_mgt_system.authentication_userid,
      :secret_access_key => ext_mgt_system.authentication_password,
      :region => ext_mgt_system.provider_region
      )
    return Object::const_get("AWS").const_get("#{type}").new()
  end

    # Get the AWS Management System from teh various options available
  def get_mgt_system()
    aws_mgt = nil
    if @task
      if @task.get_option(:mid)
        aws_mgt = $evm.vmdb(:ems_amazon).find_by_id(@task.get_option(:mid))
        log(:info, "Got AWS Mgt System from @task.get_option(:mid)")
      end
    elsif $evm.root['vm']
      vm = $evm.root['vm']
      aws_mgt = vm.ext_management_system
      log(:info, "Got AWS Mgt System from VM #{vm.name}")
    else
      aws_mgt = $evm.vmdb(:ems_amazon).first
      log(:info, "Got First Available AWS Mgt System from VMDB")
    end
    return aws_mgt
  end

    # basic retry logic
  def retry_method(retry_time="1.minute")
    log(:info, "Retrying in #{retry_time} seconds")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  log(:info, "Begin Automate Method")

  dump_root
 
  # Get the task object from root
  @task = $evm.root['service_template_provision_task']
  if @task
    # List Service Task Attributes
    @task.attributes.sort.each { |k, v| log(:info, "#{@method} - Task:<#{@task}> Attributes - #{k}: #{v}")}

    # Get destination service object
    @service = @task.destination
    log(:info,"Detected Service:<#{@service.name}> Id:<#{@service.id}>")
  end

  require 'aws-sdk'

    # get the AWS Management System Object
  aws_mgt = get_mgt_system
  log(:info, "AWS Mgt System is #{aws_mgt.inspect}")

  ec2 = get_aws_object(aws_mgt)
  log(:info, "Got EC2 Object: #{ec2.inspect}")

  instance_ids = @task.get_option(:aws_deployed_instances).split(',')
  
  count = 0
  instance_ids.each {|instance_id|
    instance = ec2.instances[instance_id]
    password_response = ec2.client.get_password_data({
      :instance_id => instance.id
      })
    count += 1 if password_response.password_data.nil?
  }

  if count > 0
    @task.message = "Gathering Instance Passwords, Please be Patient"
    log(:info, "Still gathering instance passwords, #{count} instances still")
    retry_method
  end

  private_key_data = @task.get_option(:aws_private_key)
  ssl_private_key = OpenSSL::PKey::RSA.new(private_key_data)

  instance_passwords = []

  instance_ids.each {|instance_id|
    instance = ec2.instances[instance_id]
    password_response = ec2.client.get_password_data({
      :instance_id => instance.id
      })

    decoded = Base64.decode64(password_response.password_data)
    decrypted = ssl_private_key.private_decrypt(decoded)
    instance_passwords.push({ :instance_id => instance.id, :password => decrypted })
    log(:info, "Got Instance ID #{instance.id} with password #{decrypted}")
  }

  instances = ""
  instance_passwords.each { |id, password| instances = "#{instances} #{id}" }

  @service.custom_set("INSTANCES", instances)
  aws_mgt.refresh
  #
  # Now, we have all the instances and passwords, send an email to each student with the EIP and password
  # Then initiate a refresh of tHE EMS and associate all instances in CF with the service
  #

  elastic_ip = []
  if @task.get_option(:allocate_elastic_ip) && @task.get_option(:allocate_elastic_ip).to_s == "1"
    log(:info, "Allocating Elastic IPs")
    instance_ids.each {|instance_id|
      ip = nil
      begin 
        ip = ec2.elastic_ips.allocate({ :vpc => true })
      rescue AWS::EC2::Errors::AddressLimitExceeded => limiterr
        log(:error, "EC2 Elastic IP Limit Reached: #{limiterr}")
        log_err(limiterr)
        $evm.execute(:send_email, @task.get_option(:email), nil, "EC2 Elastic IP Error", 
          "Unable to assign elasitc ips #{limiterr}: <br/>#{limiterr.backtrace.join("<br />\n")}")
        @service.custom_set("ELASTIC_IPS", "FAILED to Allocate: #{limiterr}")
      end
      if ip
        log(:info, "Allocated #{ip}")
        ec2.instances[instance_id].associate_elastic_ip(ip)
        log(:info, "Associated #{ip} with #{instance_id}")
        elastic_ip.push(ip.public_ip)
      end
    }
  end

  email_body =  "<br />Greetings from the Red Hat CloudForms Demo Environment<br /><br />\n"
  email_body += "Your Training Class Has Been Deployed. Here are the login credentials for each Windows Host<br /><br />\n"
  count = 1
  instance_passwords.each { |instance_info|
    ec2_instance = ec2.instances["#{instance_info[:instance_id]}"]
    ec2_instance.add_tag("Name", :value => "#{@task.get_option(:class_name)}-desktop-#{count}")
    email_body += "<b>Instance Name:</b> #{@task.get_option(:class_name)}-desktop-#{count}<br />\n"
    email_body += "<b>Instance ID:</b> #{instance_info[:instance_id]}<br />\n"
    email_body += "<b>RDP Address:</b> #{ec2_instance.ip_address}<br />\n"
    email_body += "<b>Password:</b> #{instance_info[:password]}<br />\n"
    email_body += "<br />\n"
    count += 1
  }

  if @task.get_option(:allocate_elastic_ip) && @task.get_option(:allocate_elastic_ip).to_s == "1"
    email_body += "<br /><b><i>NOTE: Your Deployment is using Elastic IP Addresses</i></b><br /><br />\n\n"
    @service.custom_set("ELASTIC_IPS", "In-Use: #{elastic_ip.join(",")}")
  end

  email_body += "-Thank you from the Red Hat CloudForms Demo Environment<br />\n"
  email_body += "-Your Instances will display in your CloudForms service momentarily<br />\n"

  log(:info, "Sending Mail to #{@task.get_option(:email)} with subject #{@service.name} and body\n#{email_body}")

  $evm.execute(:send_email, @task.get_option(:email), nil, "#{@service.name} Deployment Complete", email_body)

  log(:info, "Exit Automate Method")

rescue => err
  log_err(err)
  $evm.root['ae_result'] = "error"
  @task.message = "Error Provisioning Public AMI: #{err.class} '#{err}'"
  @service.remove_from_vmdb if @service && @task && @task.get_option(:remove_from_vmdb_on_fail)
  exit MIQ_ABORT
end
