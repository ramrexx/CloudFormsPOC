# List_Resource_Pools.rb
#
# Description: List the resource pools associated with a provider
#

# Get vm object from root
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" if vm.nil?

provider = vm.ext_management_system
$evm.log(:info, "Detected Provider: #{provider.name}")

pools_hash = {'<choose>' => nil}

provider.resource_pools.each do |pool|
  #next unless template.tagged_with?('prov_scope', 'all')
  #next unless template.vendor.downcase == 'redhat'
  pools_hash[pool[:name]] = pool[:ems_ref]
end

$evm.object['values'] = pools_hash
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")
