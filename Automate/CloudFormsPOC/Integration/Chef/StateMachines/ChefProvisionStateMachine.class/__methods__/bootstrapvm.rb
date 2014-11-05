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
    @method = 'BootstrapVM'
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
    log(:info, "Executing command: #{cmd}")
    begin
      result = LinuxAdmin.run!(cmd)
      log(:info, "Inspecting output: #{result.output.inspect}")
      log(:info, "Inspecting error: #{result.error.inspect}")
      log(:info, "Inspecting exit_status: #{result.exit_status.inspect}")
      return result
    rescue => admincmderr
      log(:error, "Error running #{cmd}: #{admincmderr}")
      log(:error, "Backtrace: #{admincmderr.backtrace.join('\n')}")
      return false
    end
  end

  def verify_bootstrapped(vmname)
    vmname = vmname.downcase
    log(:info, "Finding #{vmname} in chef node list")
    cmd = "/var/www/miq/knife_wrapper.sh node list"
    result = run_linux_admin(cmd)
    if result.exit_status.zero?
      hosts = result.output.split("\n")
      for host in hosts
        if host == vmname
          log(:info, "Found #{host} in knife node list")
          return true
        end
      end
      log(:info, "Did not find #{vmname} in #{hosts.inspect}")
      return false
    else
      log(:error, "Error running #{cmd}, failing")
      return false
    end
  end

  def chef_bootstrap(ipaddr)
    username = $evm.object['bootstrapUsername']
    password = $evm.object.decrypt('bootstrapPassword')
    cmd = "/var/www/miq/knife_wrapper.sh bootstrap #{ipaddr} -x #{username} -P #{password}"
    result = run_linux_admin(cmd)
    if result.exit_status.zero?
      log(:info, "Successfully bootstrapped #{ipaddr}")
      return true
    else
      log(:error, "Error bootstrapping #{ipaddr}")
      raise "Error bootstrapping #{ipaddr}: #{result.error.inspect}"
    end
    return false
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  vm = nil

  case $evm.root['vmdb_object_type']
  when 'miq_provision'
    log(:info, "Getting VM from MIQ Provision Object")
    vm = prov.vm
    log(:info, "Got VM #{vm.name} from miq_provision")
  when 'vm'
    log(:info, "Getting vm from $evm.root['vm']")
    vm = $evm.root['vm']
    log(:info, "Got #{vm.name} from $evm.root['vm']")
  end

  # raise an exception if the VM object is nil
  raise "VM Object is nil, cannot bootstrap nil" if vm.nil?

  log(:info, "EVM Object: #{$evm.object.inspect}")

  # Since this may support provisioning we need to put in retry logic to wait
  # until IP Addresses are populated.
  unless vm.ipaddresses.empty?
    non_zeroconf = false
    vm.ipaddresses.each do |ipaddr|
      non_zeroconf = true unless ipaddr.match(/^(169.254|0)/)
      log(:info, "VM:<#{vm.name}> IP Address found #{ipaddr} (#{non_zeroconf})")
    end
    if non_zeroconf
      log(:info, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> present.")
      $evm.root['ae_result'] = 'ok'
    else
      log(:warn, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> not present.")
      retry_method("1.minute")
    end
  else
    log(:warn, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> not present.")
    retry_method("1.minute")
  end

  # User guest hostname first otherwise use the instance name
  unless vm.hostnames.blank?
    vmname = vm.hostnames.first
  else
    vmname = vm.name
    #vmname = "#{vmname}.phx.salab.redhat.com" unless vmname.match(/phx.salab.redhat.com$/)
  end

  bootstrapped = verify_bootstrapped(vmname)
  bootstrapped = chef_bootstrap(vm.ipaddresses.first) unless bootstrapped
  if bootstrapped
    log(:info, "Successfully bootstrapped #{vmname}")
    obj = $evm.object
    obj['status'] = "active"
    if vm.custom_get("CHEF_Bootstrapped").nil?
      vm.custom_set("CHEF_Bootstrapped", "YES: #{Time.now}")
    end
  else
    obj['status'] = "inactive"
    log(:error, "Unable to bootstrap #{vmname} #{vm.ipaddresses.first}")
    exit MIQ_ABORT
  end

  obj['vm'] = vm

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
