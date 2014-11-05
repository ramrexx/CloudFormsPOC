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

  def dump_vm(vm)
    log(:info, "VM:<#{vm.name}> Begin Attributes [vm.attributes]")
    vm.attributes.sort.each { |k, v| log(:info, "VM:<#{vm.name}> Attributes - #{k}: #{v.inspect}")}
    log(:info, "VM:<#{vm.name}> End Attributes [vm.attributes]")
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

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  username = nil || $evm.object['username']
  password = nil || $evm.object.decrypt('password')

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

  dump_vm(vm)

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
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = '1.minute'
      exit MIQ_OK
    end
  else
    log(:warn, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> not present.")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
    exit MIQ_OK
  end
  
  # VM Has not yet been bootstrapped in chef
  if vm.custom_get("CHEF_Bootstrapped").blank?
    cmd = "/var/www/miq/knife_wrapper.sh bootstrap #{vm.ipaddresses.first} -x #{username} -P #{password}"
    result = run_linux_admin(cmd)
    if result
      log(:info, "Successfully bootstrapped #{vm.name}: #{result}")
      vm.custom_set("CHEF_Bootstrapped", "YES: #{Time.now}}")
      vm.custom_set("CHEF_Failure", nil)
    else
      log(:error, "Unable to bootstrap #{vm.name}, please check CHEF stacktrace")
      vm.custom_set("CHEF_Failure", "Bootstrap: #{Time.now}")
      raise "Exiting due to chef bootstrap failure"
    end
  end

  chef_role = $evm.root['dialog_chef_role'] rescue nil
  chef_cookbook = $evm.root['dialog_chef_cookbook'] rescue nil

  # Add the roles and cookbook separately.  If you add them all at once, then if one
  # item failes, all items fail.  This way is a little more code, but more resilience

  vmname = vm.name
  vmname = "#{vmname}.phx.salab.redhat.com" unless vmname.match(/phx.salab.redhat.com$/)

  log(:info, "Running knife commands using #{vmname} because hey, DNS is borked")

  unless chef_role.blank?
    cmd = "/var/www/miq/knife_wrapper.sh node run_list add #{vmname} role[#{chef_role}]"
    result = run_linux_admin(cmd)
    log(:info, "Chef role add command returned #{result}")
    if result
      log(:info, "Role #{chef_role} added successfully")
      current = vm.custom_get("CHEF_Roles")
      if current.nil?
        vm.custom_set("CHEF_Roles", "#{chef_role}")
      else
        vm.custom_set("CHEF_Roles", "#{current} #{chef_role}")
      end
    else
      log(:error, "Role #{chef_role}, failed to add.  Please check VM for logs")
    end
  end

  unless chef_cookbook.blank?
    cmd = "/var/www/miq/knife_wrapper.sh node run_list add #{vmname} recipe[#{chef_cookbook}]"
    result = run_linux_admin(cmd)
    log(:info, "Chef cookbook add command returned #{result}")
    if result
      log(:info, "Role #{chef_cookbook} added successfully")
      current = vm.custom_get("CHEF_Cookbook")
      if current.nil?
        vm.custom_set("CHEF_Cookbook", "#{chef_cookbook}")
      else
        vm.custom_set("CHEF_Cookbook", "#{current} #{chef_cookbook}")
      end
    else
      log(:error, "Role #{chef_role}, failed to add.  Please check VM for logs")
    end
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
