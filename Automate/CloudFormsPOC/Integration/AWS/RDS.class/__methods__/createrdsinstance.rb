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
    else
      aws_mgt = $evm.vmdb(:ems_amazon).first
      log(:info, "Got First Available AWS Mgt System from VMDB")
    end
    return aws_mgt
  end

  # Get the Relevant RDS Options from the available
  # Service Template Provisioning Task Options
  def get_rds_options_hash()
    options_regex = /^:rds_(.*)/
    options_hash = {}
    @task.options.each {|key, value|
      options_hash[key] = value if options_regex =~ key
    }
    log(:info, "Returning Options Hash: #{options_hash.inspect}")
  end

  # BEGIN MAIN #

  log(:info, "Begin Automate Method")

  dump_root
 
  # Get the task object from root
  @task = $evm.root['service_template_provision_task']
  if @task
    # List Service Task Attributes
    @task.attributes.sort.each { |k, v| log(:info, "#{@method} - Task:<#{service_template_provision_task}> Attributes - #{k}: #{v}")}

    # Get destination service object
    @service = service_template_provision_task.destination
    log(:info,"#{@method} - Detected Service:<#{service.name}> Id:<#{service.id}>")
  end

  require 'aws-sdk'

  # get the AWS Management System Object
  aws_mgt = get_mgt_system
  log(:info, "AWS Mgt System is #{aws.inspect}")


  # Get an RDS Client Object via the AWS SDK
  client = get_rds_from_management_system(aws_mgt).client 
  log(:info, "Got AWS-SDK RDS Client: #{client.inspect}")

  # Get the relevant RDS Options hash from the provisioning task
  # these will be passed unchanged to create_db_instance.  It is up to
  # the catalog item initialization to validate and process these into
  # options on the task item
  options_hash = get_rds_options_hash
  log(:info, "Creating RDS Instace with options: #{options_hash.inspect}")
  db_instance = client.create_db_instance(options_hash)
  log(:info, "DB Instance Created: #{db_instance.inspect}")
  
  # The instance is now in creating state, set some attributes on the service object
  @service.custom_set("rds_db_instance_identifier", db_instance[:db_instance_identifier])
  @service.custom_set("rds_preferred_backup_window", db_instance[:preferred_backup_window])
  @service.custom_set("rds_engine", "#{db_instance[:engine]} #{db_instance[:engine_version]}")
  @service.custom_set("rds_db_instance_class", db_instance[:db_instance_class])
  @service.custom_set("rds_publicly_accessible", db_instance[:publicly_accessible].to_s)
  @service.custom_set("MID", "#{aws_mgt.id}")

  # Make sure these options are available so they can be used for notification later
  # (if needed)
  @task.set_option(:rds_engine_version, db_instance[:engine_version])
  @task.set_option(:rds_engine, db_instance[:engine])

  # End this automate method
  log(:info, "End Automate Method")

  # END MAIN #

rescue => err
  log_err(err)
  $evm.root['ae_result'] = "error"
  @task.message = "Error Provisioning RDS Instance: #{err.class} '#{err}'"
  @service.remove_from_vmdb if @service && @task && @task.get_option(:remove_from_vmdb_on_fail)
  exit MIQ_ABORT
end
