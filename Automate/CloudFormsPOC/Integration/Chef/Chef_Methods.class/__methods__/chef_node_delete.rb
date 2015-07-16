begin
  
  # Method for logging
  def log(level, message)
    $evm.log(level, "#{message}")
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

  def run_linux_admin(cmd, timeout=10)
    require 'linux_admin'
    require 'timeout'
    begin
      Timeout::timeout(timeout) {
        log(:info, "Executing #{cmd} with timeout of #{timeout} seconds")
        result = LinuxAdmin.run(cmd)
        log(:info, "--> Inspecting output: #{result.output.inspect}")
        log(:info, "--> Inspecting error: #{result.error.inspect}") unless result.error.blank? 
        log(:info, "--> Inspecting exit_status: #{result.exit_status.inspect}")
        return result
      }
    rescue => timeout
      log(:error, "Error executing chef: #{timeout.class} #{timeout} #{timeout.backtrace.join("\n")}")
      return false
    end
  end

  log(:info, "Begin Automate Method")

  vm = nil
  case $evm.root['vmdb_object_type']
    when 'miq_provision'
      log(:info, "Getting VM from MIQ Provision Object")
      prov = $evm.root['miq_provision']
      vm = prov.vm
      log(:info, "Got VM #{vm.name} from miq_provision")
    when 'vm'
      log(:info, "Getting vm from $evm.root['vm']")
      vm = $evm.root['vm']
      log(:info, "Got #{vm.name} from $evm.root['vm']")
  end
  raise "Unable to find vm object from $evm.root" if vm.nil?

  dump_root
  dump_vm(vm)

  log(:info, "Removing #{vm.name} from chef if it's there")
  chef_node_name = vm.custom_get("CHEF_Node_Name")
  chef_node_name = vm.hostnames.first if chef_node_name.blank?
  chef_node_name = "#{vm.name}" if chef_node_name.blank?
  chef_bootstrap = vm.tags(:chef_bootstrapped).first
  chef_environment = vm.custom_get("CHEF_Environment")
  chef_environment = vm.tags(:chef_environment).first if chef_environment.blank?
  chef_environment = $evm.object['chef_environment'] if chef_environment.blank?
  chef_environment = "_default" if chef_environment.blank?

  log(:info, "VM <#{vm.name} chef_bootstrapped = #{chef_bootstrap}")
  unless chef_bootstrap == "true"
    log(:info, "VM: <#{vm.name}> Chef is not bootstrapped on this node as far as we know '#{vm.tags(:chef_bootstrapped).first}'")
    exit MIQ_OK 
  end
  log(:info, "Got chef node name #{chef_node_name}")
  begin
    cmd = "/usr/bin/knife node delete #{chef_node_name} -E #{chef_environment} -y"
    result = run_linux_admin(cmd, 5)
    log(:info, "Chef Delete Result: #{result.inspect}")
  rescue => cheferr
    log(:error, "ERROR, Chef Delete Failed")
    log(:error, "[#{cheferr}] #{cheferr.backtrace.join("\n")}\n")
    exit MIQ_OK
  end

  vm.custom_set("CHEF_Bootstrapped", nil)
  vm.custom_set("CHEF_Node_Name", nil)
  vm.custom_set("CHEF_Recipes", nil)
  vm.custom_set("CHEF_Roles", nil)
  vm.custom_set("CHEF_Environment", nil)
  vm.custom_set("CHEF_Run_List", nil)

  vm.tag_unassign("chef_bootstrapped/true")
  vm.tag_unassign("chef_bootstrapped/false")

  vm.tags(:chef_role).each { |tag|
    log(:info, "Untagging #{tag}")
    vm.tag_unassign("chef_role/#{tag}")
  }

  vm.tags(:chef_recipe).each { |tag| 
    log(:info, "Untagging #{tag}")
    vm.tag_unassign("chef_recipe/#{tag}")
  }

  log(:info, "End automate method for #{vm.name}")
 # Ruby rescue
rescue => err
  log(:error, "Unexpected Chef Delete Error: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_OK
end
