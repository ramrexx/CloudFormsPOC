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

  log(:info, "Begin Automate Method")

  dump_root()

  require 'aws-sdk'

  aws_mgt = nil

  if $evm.root['dialog_mid']
    aws_mgt = $evm.vmdb(:ems_amazon).find_by_id($evm.root['dialog_mid'])
    log(:info, "Got AWS Mgt System from $evm.root['dialog_mid] #{aws_mgt.hostname}")
  elsif $evm.root['vm']
    vm = $evm.root['vm']
    aws_mgt = vm.ext_management_system
    log(:info, "Got AWS Mgt System from VM #{vm.name}")
  else
    aws_mgt = $evm.vmdb(:ems_amazon).first
    log(:info, "Got AWS Mgt System from VMDB")
  end

  log(:info, "AWS: #{aws_mgt.inspect}")

  AWS.config(
    :access_key_id => aws_mgt.authentication_userid,
    :secret_access_key => aws_mgt.authentication_password,
    :region => aws_mgt.name
    )

  ec2 = AWS::EC2.new()
  log(:info, "Got AWS-SDK connection: #{ec2.inspect}")

  az_hash = {}

  ec2.availability_zones.each { |az| az_hash[az.name] = az.name }

  az_hash[nil] = nil

  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = az_hash
  log(:info, "Dynamic drop down values: #{$evm.object['values']}")

  log(:info, "Exit Automate Method")

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
