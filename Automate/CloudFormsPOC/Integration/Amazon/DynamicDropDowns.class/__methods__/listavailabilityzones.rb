# ListAvailabilityZones.rb
#
# Description: List all Availability Zones in Amazon
#
begin
  require 'aws-sdk'

  $evm.root.attributes.sort.each { |k, v| $evm.log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}


  aws_mgt = nil

  if $evm.root['dialog_mid']
    aws_mgt = $evm.vmdb(:ems_amazon).find_by_id($evm.root['dialog_mid'])
    $evm.log(:info, "Got AWS Mgt System from $evm.root['dialog_mid] #{aws_mgt.hostname}")
  elsif $evm.root['vm']
    vm = $evm.root['vm']
    aws_mgt = vm.ext_management_system
    $evm.log(:info, "Got AWS Mgt System from VM #{vm.name}")
  else
    aws_mgt = $evm.vmdb(:ems_amazon).first
    $evm.log(:info, "Got AWS Mgt System from VMDB")
  end

  $evm.log(:info, "AWS: #{aws_mgt.inspect}")

  AWS.config(
    :access_key_id => aws_mgt.authentication_userid,
    :secret_access_key => aws_mgt.authentication_password,
    :region => aws_mgt.name
  )

  ec2 = AWS::EC2.new()
  $evm.log(:info, "Got AWS-SDK connection: #{ec2.inspect}")

  az_hash = {}

  ec2.availability_zones.each { |az| az_hash[az.name] = az.name }

  az_hash[nil] = nil

  $evm.object['values'] = az_hash
  $evm.log(:info, "Dynamic drop down values: #{$evm.object['values']}")

rescue => err
  (dbtype_hash||={})["#{err.class}: #{err}"] = "#{err.class}: #{err}"
  $evm.object['values'] = dbtype_hash
  $evm.log(:error, "ERROR: Dynamic drop down values: #{$evm.object['values']}")
end
