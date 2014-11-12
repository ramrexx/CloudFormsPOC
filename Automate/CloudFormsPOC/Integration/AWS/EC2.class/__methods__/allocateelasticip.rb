begin
  @method = "allocateElasticIP"

  def log(level, msg)
    $evm.log(level, "<#{@method}>:<#{level.downcase}>: #{msg}")
  end

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def get_ec2_from_management_system(ext_management_system)
  	AWS.config(
      :access_key_id => ext_management_system.authentication_userid,
      :secret_access_key => ext_management_system.authentication_password
    )
    return AWS::EC2.new().regions[aws.hostname]
  end

  log(:info, "Begin Automate Method")

  dump_root

  require 'aws-sdk'
  vm = nil
  case $evm.root['vmdb_object_type']
    when 'vm'
      vm = $evm.root['vm']
  end
  raise "Unable to find vm in $evm.root" if vm.nil?

  ec2 = get_ec2_from_management_system(vm.ext_management_system)

  ip = ec2.elastic_ips.allocate 
  log(:info, "Allocated #{ip}")

  ip.delete()
  log(:info, "Deleted IP #{ip}")

  log(:info, "End Automate Method")

rescue => err
  log(:error, "#{err.class} [#{err}] #{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
