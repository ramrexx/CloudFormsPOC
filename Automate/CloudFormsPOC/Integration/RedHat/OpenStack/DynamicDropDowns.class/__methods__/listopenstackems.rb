list = $evm.vmdb(:ems_openstack).all
for item in list
  (openstack_hash||={})[item.id] = item.name
end

openstack_hash[nil] = nil
$evm.object['values'] = openstack_hash
$evm.log(:info, "Dynamic drop down values: #{$evm.object['values']}")
