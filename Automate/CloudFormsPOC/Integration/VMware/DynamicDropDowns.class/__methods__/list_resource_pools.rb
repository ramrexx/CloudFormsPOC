# List_Resource_Pools.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: List the resource pools associated with a provider
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # Get vm object from root
  vm = $evm.root['vm']
  raise "Missing $evm.root['vm'] object" if vm.nil?

  provider = vm.ext_management_system
  $evm.log(:info, "Detected Provider: #{provider.name}")

  pools_hash = {}

  provider.resource_pools.each do |pool|
    log(:info, "Looking at resource_pool: #{pool.name} id: #{pool.id} ems_ref: #{pool.ems_ref}")
    #next unless template.tagged_with?('prov_scope', 'all')
    #next unless template.vendor.downcase == 'vmware'
    if vm.resource_pool && vm.resource_pool.ems_ref == pool.ems_ref
      pools_hash[pool[:ems_ref]] = "<current> #{pool[:name]}"
    else
      pools_hash[pool[:ems_ref]] = pool[:name]
    end
  end
  pools_hash[nil] = '< Choose a pool >'

  $evm.object['values'] = pools_hash
  $evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  @task.finished("#{err}") if @task
  exit MIQ_ABORT
end
