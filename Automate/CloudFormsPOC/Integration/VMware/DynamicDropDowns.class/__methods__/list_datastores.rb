# List_Datastores.rb
#
# Description: List the datastores associated with a provider
#

# Get vm object from root
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" if vm.nil?

provider = vm.ext_management_system
$evm.log(:info, "Detected Provider: #{provider.name}")

datastores_hash = {}

provider.storages.each do |storage|
  #next unless template.tagged_with?('prov_scope', 'all')
  #next unless template.vendor.downcase == 'vmware'
  if vm.storage.ems_ref == storage.ems_ref
    datastores_hash[storage[:ems_ref]] = "<current> #{storage[:name]}"
  else
  	datastores_hash[storage[:ems_ref]] = storage[:name]
  end
end

$evm.object['values'] = datastores_hash
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")
