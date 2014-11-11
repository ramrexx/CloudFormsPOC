
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

  # convenience method to get an AWS::RDS Object using
  # the AWS EVM Management System
  def get_rds_from_management_system(ext_management_system)
    AWS.config(
      :access_key_id => ext_management_system.authentication_userid,
      :secret_access_key => ext_management_system.authentication_password,
      :region => ext_management_system.name
    )
    return AWS::RDS.new()
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
    elsif @service
      mid = @service.custom_get("MID")
      aws_mgt = $evm.vmdb(:ems_amazon).find_by_id(mid)
      log(:info, "Got AWS Mgt System from Service Custom Attribute")
    else
      aws_mgt = $evm.vmdb(:ems_amazon).first
      log(:info, "Got First Available AWS Mgt System from VMDB")
    end
    return aws_mgt
  end

  # basic retry logic
  def retry_method(retry_time=1.minute)
    log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end


  log(:info, "Begin Automate Method")


  status = "available"

  case $evm.root['vmdb_object_type']
  when 'service_template_provision_task'
    @task = $evm.root['service_template_provision_task']
    @service = @task.destination
    @task.attributes.sort.each { |k, v| log(:info, "#{@method} - Task:<#{@task}> Attributes - #{k}: #{v}")}
    log(:info,"Detected Service:<#{@service.name}> Id:<#{@service.id}>")
  when 'service'
    @service = $evm.root['service']
    log(:info,"Detected Service:<#{@service.name}> Id:<#{@service.id}>")
    status = nil
  end
  

  require 'aws-sdk'
  aws_mgt = get_mgt_system
  log(:info, "Got AWS Mgt System: #{aws_mgt.inspect}")

  client = get_rds_from_management_system(aws_mgt).client
  log(:info, "Got AWS RDS Client: #{client}")

  db_instance = nil
  instance_name = @service.custom_get("rds_db_instance_identifier")
  instance_name ||= @task.get_option(:rds_db_instance_identifier)  unless @task.nil?
  log(:info, "Checking status on #{instance_name}")
  begin
    db_instance = client.describe_db_instances({ 
      :db_instance_identifier => instance_name 
    })[:db_instances].first
  rescue AWS::RDS::Errors::DBInstanceNotFound => describerr
    log_err(describerr)
  end
  log(:info, "Found DB Instance: #{db_instance.inspect rescue "NOT FOUND"}")

  if status
    unless db_instance[:db_instance_status] == status
      log(:info, "Retrying because db instance status is '#{db_instance[:db_instance_status]}'")
      @service.custom_set("CURRENT_STATUS", "#{db_instance[:db_instance_status]} @ #{Time.now}")
      @task.message = "DB Instance Provisioning Started, it may take a while.  Current Status: #{db_instance[:db_instance_status]} @ #{Time.now}"
      retry_method
    end
  else
    if db_instance
      log(:info, "Retrying because db instance status is '#{db_instance[:db_instance_status]}")
      @service.custom_set("CURRENT_STATUS", "#{db_instance[:db_instance_status]} @ #{Time.now}")
      retry_method
    end
  end

  log(:info, "Exiting normally, instance status is now #{status rescue "deleted"}")
  if status.nil?
    @service.remove_from_vmdb 
  else
    @service.custom_set("CURRENT_STATUS", nil)
    @service.custom_set("rds_endpoint", "#{db_instance[:endpoint][:address]}:#{db_instance[:endpoint][:port]}")
  end
  log(:info, "End Automate Method")

rescue => err
  log_err(err)
  $evm.root['ae_result'] = "error"
  @task.message = "Error Provisioning RDS Instance: #{err.class} '#{err}'"
  exit MIQ_ABORT
end
