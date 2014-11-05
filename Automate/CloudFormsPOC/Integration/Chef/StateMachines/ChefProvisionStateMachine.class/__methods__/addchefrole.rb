###################################
#
# CFME Automate Method: AddChefRole
#
# Notes: This method uses a kinfe wrapper to bootstrap a Chef client
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'AddChefRole'
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

  def add_chef_role(vmname, chef_role)
    log(:info,"Adding role '#{chef_role}' to '#{vmname}'")
    cmd = "/var/www/miq/knife_wrapper.sh node run_list add #{vmname} " +
          "role[#{chef_role}]"
    result = run_linux_admin(cmd)
    if result.exit_status.zero?
      log(:info, "Added chef role #{chef_role} successfully")
    else
      log(:error, "Error adding chef role #{chef_role}")
      raise "Error adding chef role #{chef_role}"
    end
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  status = $evm.object['status']
  vm = $evm.object['vm']
  log(:info, "Got #{status} from $evm.object")  unless status.nil?
  log(:info, "Got #{vm.name} from $evm.object") unless vm.nil?

  # raise an exception if the VM object is nil
  if status.nil?
    log(:error, "No 'status' field in $evm.object")
    exit MIQ_STOP
  end

  if vm.nil?
    log(:error, "No 'vm' field in $evm.object")
    exit MIQ_STOP
  end

  if status != "active"
    log(:error, "Status is not active: '#{status}'")
    exit MIQ_STOP
  end

  log(:info, "EVM Object: #{$evm.object.inspect}")

  # User guest hostname first otherwise use the instance name
  unless vm.hostnames.blank?
    vmname = vm.hostnames.first
  else
    vmname = vm.name
    #vmname = "#{vmname}.phx.salab.redhat.com" unless vmname.match(/phx.salab.redhat.com$/)
  end

  chef_role = $evm.root['dialog_chef_role'] rescue nil
  unless chef_role.blank?
    add_chef_role(vmname, chef_role)
  else
    log(:info, "No chef role specified, ignoring")
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
