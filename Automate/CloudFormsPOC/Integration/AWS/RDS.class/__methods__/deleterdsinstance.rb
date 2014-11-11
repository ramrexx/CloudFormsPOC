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

  log(:info, "Begin Automate Method")

  require 'aws-sdk'

  # Will this work?
  service = $evm.root['service']
  raise "Unable to find service in $evm.root['service']" if service.nil?

  aws_mgt = $evm.vmdb(:ems_amazon).find_by_id(service.custom_get("MID"))
  raise "Unable to find Management System with ID #{service.custom_get("MID")}" if aws_mgt.nil?
  log(:info, "Found AWS Mgt System #{aws_mgt.name}")

  client = get_rds_from_management_system(aws_mgt).client
  log(:info, "Got AWS Client #{client.inspect}")

  raise "Did not find rds_db_instance_identifier attribute, can't delete" if service.custom_get("rds_db_instance_identifier").blank?

  begin
    delete_status = client.delete_db_instance({
      :db_instance_identifier => service.custom_get("rds_db_instance_identifier"),
      :skip_final_snapshot => true
      })
  rescue AWS::RDS::Errors::DBInstanceNotFound => dberr
    log_err(dberr)
    log(:info, "Database is already gone, moving forward in the state machine")
  end

  log(:info, "Delete Issued: #{delete_status.inspect}")

  log(:info, "End Automate Method")

rescue => err
  log_err(err)
  $evm.root['ae_result'] = "error"
  exit MIQ_ABORT
end
