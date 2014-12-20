
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

  #ami_mapping = {
  # "East (N. Virginia)" => "ami-c49c0dac",
  # "US West (Oregon)" => "ami-a13d6891",
  # "US West (N. California)" => "ami-45332200",
  # "EU West (Ireland)" => "ami-905fe9e7",
  # "Asia Pacific (Singapore)" => "ami-e01f3db2",
  # "Asia Pacific (Sydney)" => "ami-efa8c6d5",   
  # "Asia Pacific (Tokyo)" => "ami-8580ba84",  
  # "South America (Sao Paulo)" => "ami-f501b7e8"
  #}

    # get the AWS Management System Object
  aws_mgt = get_mgt_system
  log(:info, "AWS Mgt System is #{aws_mgt.inspect}")

  ec2 = get_aws_object(aws_mgt)
  log(:info, "Got EC2 Object: #{ec2.inspect}")

  keypair_name = @service.custom_get("KEYPAIR_NAME")
  secgroup_id = @service.custom_get("SECURITY_GROUP")

  security_group = ec2.security_groups["#{secgroup_id}"]
  keypair = ec2.key_pairs.detect {|kp| "#{kp.name}" == keypair_name }

  region_name = aws_mgt.provider_region
  region_name.gsub! "-", "_"

  log(:info, "Looking for key #{region_name}")

  ami = $evm.object[region_name]
  raise "No ami found in $evm.object for regin #{aws_mgt.provider_region}" if ami.nil?

  vpc = ec2.vpcs.first

  count = 1
  count = @task.get_option(:student_count).to_i if @task.get_option(:student_count)

  instances = ec2.instances.create({
    :image_id => ami,
    :instance_type => @task.get_option(:instance_flavor),
    :count => count,
    :key_pair => keypair,
    :subnet => vpc.subnets.first.subnet_id,
    :security_groups => security_group.name
    })

  id_array = []
  if count > 1
    instances.each {|inst| 
      id_array.push(inst.id)
    }
  else
    id_array.push(instances.id)
  end

  @task.set_option(:aws_deployed_instances, "#{id_array.join(",")}")
  @task.message = "Deployed #{count} instances from #{ami} in #{aws_mgt.provider_region}"

  log(:info, "Set :aws_deployed_instances to #{@task.get_option(:aws_deployed_instances)}")

  log(:info, "Exit Automate Method")

rescue => err
  log_err(err)
  $evm.root['ae_result'] = "error"
  @task.message = "Error Provisioning Public AMI: #{err.class} '#{err}'"
  $evm.root['ae_reason'] = "Error Provisioning Public AMI: #{err.class} '#{err}'"
  @service.remove_from_vmdb if @service && @task && @task.get_option(:remove_from_vmdb_on_fail)
  exit MIQ_ABORT
end
