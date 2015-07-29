# list_service_vms.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method will build a list of vm ids attached to a service
#
service  = $evm.root['service']
$evm.log(:info, "Service: #{service.name} id: #{service.id} guid: #{service.guid} vms: #{service.vms.count}")

dialog_hash = {}

service.vms.each do |vm|
  if vm.archived?
    dialog_hash[vm.id] = "#{vm.name} [ARCHIVED] on #{service.name}"
  elsif vm.orphaned?
    dialog_hash[vm.id] = "#{vm.name} [ORPHANED] on #{service.name}"
  else
    dialog_hash[vm.id] = "#{vm.name} on #{service.name}"
  end
end

if dialog_hash.blank?
  $evm.log(:info, "No VMs found")
  dialog_hash[''] = "< No VMs found >"
else
  dialog_hash[''] = '< choose a VM >'
end

$evm.object["values"]     = dialog_hash
$evm.log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
