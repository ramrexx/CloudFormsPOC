
begin

  def log(level, msg)
    $evm.log(level, msg)
  end

  def log_err(err)
    log(:error, "#{err.class} #{err}")
    log(:error, "#{err.backtrace.join("\n")}")
  end

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def get_rds_from_management_system(ext_management_system)
    AWS.config(
      :access_key_id => ext_management_system.authentication_userid,
      :secret_access_key => ext_management_system.authentication_password,
      :region => ext_management_system.name
    )
    return AWS::RDS.new()
  end

  log(:info, "Begin Automate Method")

  dump_root

  require 'aws-sdk'

  aws_mgt = nil

  if $evm.root['dialog_mid']
    aws_mgt = $evm.vmdb(:ems_amazon).find_by_id($evm.root['dialog_mid'])
    log(:info, "Got AWS Mgt System from $evm.root['dialog_mid]")
  elsif $evm.root['vm']
    vm = $evm.root['vm']
    aws_mgt = vm.ext_management_system
    log(:info, "Got AWS Mgt System from VM #{vm.name}")
  else
    aws_mgt = $evm.vmdb(:ems_amazon).first
    log(:info, "Got AWS Mgt System from VMDB")
  end

  type = $evm.root['dialog_rds_type']
  type ||= "mysql"

  log(:info, "Type is #{type}")
  dbtype_hash = {}
  client = get_rds_from_management_system(aws_mgt).client
  log(:info, "Got RDS Client: #{client}")
  client.describe_db_engine_versions[:db_engine_versions].each { |engine_version|
    dbtype_hash[engine_version[:engine_version]] = engine_version[:engine_version] if engine_version[:engine] == type
  }
  dbtype_hash[nil] = nil
  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = dbtype_hash
  $evm.object['default_value'] = dbtype_hash.first[0]
  log(:info, "Dynamic drop down values: #{$evm.object['values']}")
  
  log(:info, "End Automate Method")

rescue => err
  log_err(err)
  dbtype_hash = {}
  dbtype_hash["#{err.class}: #{err}"] = "#{err.class}: #{err}"
  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = dbtype_hash
  log(:error, "ERROR: Dynamic drop down values: #{$evm.object['values']}")
end
