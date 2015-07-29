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
      if @task.get_option(:provider_id)
        aws_mgt = $evm.vmdb(:ems_amazon).find_by_id(@task.get_option(:provider_id))
        log(:info, "Got AWS Mgt System from @task.get_option(:provider_id)")
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
  unfound_ids = []
  instance_ids.each {|instance_id|
    vm = $evm.vmdb(:vm).all.detect { |this_vm| "#{this_vm.ems_ref}" == "#{instance_id}" }
    if vm
      log(:info, "Found VM in VMDB: #{vm.name}")

      begin
        vm.add_to_service(@service)
      rescue => sererr
        log(:error, "Error adding vm to service: #{sererr}")
      end
    else
      count += 1
      log(:info, "Unable to find VM with EMS Ref #{instance_id} in the VMDB, need to retry")
      unfound_ids.push(instance_id)
    end
  }

  if count > 0
    @task.set_option(:aws_deployed_instances, "#{unfound_ids.join(",")}")
    @task.message = "All Instances Deployed, Associating with this Service"
    aws_mgt.refresh
    retry_method("15.seconds")
  end

  log(:info, "All VMs are associated with this service")

  log(:info, "Exit Automate Method")

rescue => err
  log_err(err)
  $evm.root['ae_result'] = "error"
  @task.message = "Error Provisioning Public AMI: #{err.class} '#{err}'"
  @service.remove_from_vmdb if @service && @task && @task.get_option(:remove_from_vmdb_on_fail)
  exit MIQ_ABORT
end
