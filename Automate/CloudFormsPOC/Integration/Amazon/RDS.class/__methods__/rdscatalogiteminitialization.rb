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

  log(:info, "Begin Automate Method")

  dump_root

  # Get the Service Task
  @task = $evm.root['service_template_provision_task']
  raise "service_template_provision_task is nil in initialize" if @task.nil?
  @task.attributes.sort.each { |k, v| 
    log(:info, "#{@method} - Task:<#{@task}> Attributes - #{k}: #{v}")
  }

  # Remove this service from the VMDB when it fails
  @task.set_option(:remove_from_vmdb_on_fail, true)

  # Get the Service Object
  @service = @task.destination
  raise "service is nil in initialize" if @service.nil?
  log(:info,"Detected Service:<#{@service.name}> Id:<#{@service.id}>")

  dialog_options = @task.dialog_options
  log(:info, "Dialog Options: #{dialog_options.inspect}")

  dialog_options.each { |key, value|
    log(:info, "Dialog Key: #{key} => #{value}")
    dialog_regex = /dialog_/
    next unless dialog_regex =~ key
    # key is frozen, so make a copy and operate on it
    newkey = "#{key}"
    newkey.sub! 'dialog_', ''
    log(:info, "Setting Task Option to :#{newkey} => #{value}")
    password_regex = /^password::/
    unless password_regex =~ key
      @task.set_option(:"#{newkey}", value)
    else
      require '/var/www/miq/lib/util/miq-password.rb'
      MiqPassword.key_root = "/var/www/miq/vmdb/certs"
      newvalue = MiqPassword.decrypt(value)
      newkey.sub! 'password::', ''
      log(:info, "Found Encrypted Value, decrypting and setting: #{newkey} => #{newvalue}")
      @task.set_option(:"#{newkey}", "#{newvalue}")
    end
  }

  # Remove this service from the VMDB when it fails
  @task.set_option(:remove_from_vmdb_on_fail, true)

  @task.set_option(:rds_engine, "mysql")
  @task.set_option(:rds_engine_version, "5.6.21")

  type = @task.get_option(:rds_engine)
  type ||= "mysql"

  type += " #{@task.get_option(:rds_engine_version)}" if @task.get_option(:rds_engine_version)

  # service naming and description
  new_service_name = "Amazon RDS Instance - #{type}"
  @service.name = new_service_name
  log(:info, "Set service name to #{@service.name}")
  @service.description = "Amazon Relational Database Service Instance " + 
                         "'#{@task.get_option(:rds_db_instance_identifier)}' " +
                         "- #{@task.get_option(:rds_engine)} - #{@task.get_option(:rds_engine_version)} - " +
                         "- #{@task.get_option(:rds_db_instance_class)}"
  log(:info, "Set service description to #{@service.description}")

  # this is for testing, so enforce a 3 day retirement
  @service.retires_on = (DateTime.now + 3).strftime("%Y-%m-%d")
  @service.retirement_warn = 1
  log(:info, "Set Retires On : #{@service.retires_on}")
  log(:info, "Set Retirement Warn : #{@service.retirement_warn}")

  log(:info, "End Automate Method")

rescue => err
  log_err(err)
  $evm.root['ae_result'] = "error"
  @task.message = "Error Provisioning RDS Instance: #{err.class} '#{err}'"
  @service.remove_from_vmdb if @service && @task && @task.get_option(:remove_from_vmdb_on_fail)
  exit MIQ_ABORT
end
