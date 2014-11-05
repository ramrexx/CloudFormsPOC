###################################
#
# CFME Automate Method: Chef_Bootstrap
#
# Notes: This method uses a kinfe wrapper to bootstrap a Chef client
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'Chef_Bootstrap'
    $evm.log(level, "#{@method}: #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # basic retry logic
  def retry_method(retry_time=1.minute)
    log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  def run_linux_admin(cmd)
    require 'linux_admin'
    log(:info, "Executing #{cmd}")
    result = LinuxAdmin.run!(cmd)
    log(:info, "Inspecting output: #{result.output.inspect}")
    log(:info, "Inspecting error: #{result.error.inspect}")
    log(:info, "Inspecting exit_status: #{result.exit_status.inspect}")
    return result
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  username = nil || $evm.object['username']
  password = nil || $evm.object.decrypt('password')

  case $evm.root['vmdb_object_type']

  when 'miq_provision'
    prov = $evm.root['miq_provision']
    log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

    # get vm object from miq_provision
    vm = prov.vm
    raise "$evm.root['miq_provision'].vm not found" if vm.nil?

    # Since this is provisioning we need to put in retry logic to wait until IP Addresses are populated.
    unless vm.ipaddresses.blank?
      log(:info, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> present.")
    else
      log(:warn, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> not present.")
      retry_method()
    end

    tags = prov.get_tags
    log(:info, "Bootstrapping Chef client on VM:<#{vm.name}>")

    env = tags[:environment]
    if env.nil?
      log(:info, "Environment tag:<#{env}> missing. skipping method")
    else
      log(:info, "Environment tag:<#{env}> detected")
      cmd = "/var/www/miq/knife_wrapper_#{tr1} bootstrap #{vm.name}.mhint -x #{username} -P #{password}"
      result = run_linux_admin(cmd)
      unless result.exit_status.zero?
        log(:info, "Command: #{cmd} failed with #{result.error.inspect} exit_status: #{result.exit_status.inspect}" )
        retry_method()
      end
    end
  when 'vm'
    vm = $evm.root['vm']
    log(:info, "Bootstrapping Chef client on VM:<#{vm.name}>")

    cmd = "/var/www/miq/knife_wrapper_tr1 bootstrap #{vm.name}.mhint -x #{username} -P #{password}"
    result = run_linux_admin(cmd)
  else
    log(:info, "Invalid $evm.root['vmdb_object_type']:<#{$evm.root['vmdb_object_type']}>")
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
