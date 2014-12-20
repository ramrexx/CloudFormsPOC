
begin
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

      # basic retry logic
  def retry_method(retry_time="1.minute")
    log(:info, "Retrying in #{retry_time} seconds")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  service = $evm.root['service']
  raise "Service is nil, cannot continue" if service.nil?

  log(:info, "Got Service: #{service.id} #{service.name}")

  action = "stop" 
  action = $evm.object['action'] if $evm.object['action']

  count = 0
  service.vms.each { |vm|
    log(:info, "#{vm.name}")
    ec2 = get_aws_object(vm.ext_management_system)
    case action
    when 'stop'
      ec2_instance = ec2.instances[vm.ems_ref]
      unless "#{ec2_instance.status}" == "stopped"
        ec2_instance.stop
        log(:info, "Stopping guest: #{vm.name}: #{ec2_instance.status}")
        count +=1
      end
    when 'start'
      ec2_instance = ec2.instances[vm.ems_ref]
      unless "#{ec2_instance.status}" == "running"
        vm.start
        log(:info, "Started guest: #{vm.name}: #{ec2_instance.status}")
        count +=1
      end
    end
  }

  
  retry_method("30.seconds") if count > 0

  log(:info, "All VM actions are complete: #{action}")


  service.vms.each { |vm| vm.refresh }

  if action == "start"
    unless service.custom_get("ELASTIC_IPS")
      email_body = "Greetings once againfrom the Red Hat CloudForms Demo Environment,<br /<br />\n"
      email_body = "Your training class VMs have been restarted.  Since they did not have persistent Amazon Elastic IPs configured, here is their new address information:<br /><br />"
      service.vms.each { |vm|
        ec2 = get_aws_object(vm.ext_management_system)
        ec2_instance = ec2.instances["#{vm.ems_ref}"]
        name = ec2_instance.tags["Name"]
        email_body += "<b>Instance Name:</b> #{name}<br />\n"
        email_body += "<b>Instance ID:</b> #{ec2_instance.id}<br />\n"
        email_body += "<b><i>New</i> RDP Address:</b> #{ec2_instance.ip_address}<br />\n"
        #email_body += "<b>Password:</b> #{instance_info[:password]}<br />\n"
        email_body += "<br />\n"
      }
      email_body += "-Thank you from the Red Hat CloudForms Demo Environment<br />\n"

      $evm.execute(:send_email, "dcostako@redhat.com", nil, "#{service.name} Power Up Complete", email_body)
    end
  end




  log(:info, "Got Service: #{service.id} #{service.name}")

rescue => err
  log_err(err)
  exit MIQ_ABORT
end
