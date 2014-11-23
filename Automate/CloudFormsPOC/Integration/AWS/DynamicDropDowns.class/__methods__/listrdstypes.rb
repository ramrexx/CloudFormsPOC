# ListRDSTypes.rb
#
# Description: List all RDS types in Amazon
#
begin
  def get_rds_from_management_system(ext_management_system)
    AWS.config(
      :access_key_id => ext_management_system.authentication_userid,
      :secret_access_key => ext_management_system.authentication_password,
      :region => ext_management_system.name
    )
    return AWS::RDS.new()
  end

  $evm.root.attributes.sort.each { |k, v| $evm.log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

  require 'aws-sdk'

  if $evm.root['dialog_mid']
    aws_mgt = $evm.vmdb(:ems_amazon).find_by_id($evm.root['dialog_mid'])
    $evm.log(:info, "Got AWS Mgt System from $evm.root['dialog_mid]")
  elsif $evm.root['vm']
    vm = $evm.root['vm']
    aws_mgt = vm.ext_management_system
    $evm.log(:info, "Got AWS Mgt System from VM #{vm.name}")
  else
    aws_mgt = $evm.vmdb(:ems_amazon).first
    $evm.log(:info, "Got AWS Mgt System from VMDB")
  end

  dbtype_hash = {}

  client = get_rds_from_management_system(aws_mgt).client
  $evm.log(:info, "Got RDS Client: #{client}")
  client.describe_db_engine_versions[:db_engine_versions].each { |engine_version|
    dbtype_hash[engine_version[:engine]] = engine_version[:engine]
  }
  dbtype_hash[nil] = nil
  $evm.object['values'] = dbtype_hash
  $evm.object['default_value'] = dbtype_hash.first[0]
  $evm.log(:info, "Dynamic drop down values: #{$evm.object['values']}")

rescue => err
  (dbtype_hash||={})["#{err.class}: #{err}"] = "#{err.class}: #{err}"
  $evm.object['values'] = dbtype_hash
  $evm.log(:error, "ERROR: Dynamic drop down values: #{$evm.object['values']}")
end
