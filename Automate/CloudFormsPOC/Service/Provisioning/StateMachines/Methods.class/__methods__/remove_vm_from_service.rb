# remove_vm_from_service.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method will remove a VM from its service
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level,"#{msg}")
  end

  def dump_root()
    log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    log(:info, "End $evm.root.attributes")
    log(:info, "")
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  service  = $evm.root['service']
  if service
    log(:info, "Service: #{service.name} id: #{service.id} guid: #{service.guid} vms: #{service.vms.count}")
    vm_search = $evm.root['dialog_vm_id'] || $evm.root['dialog_vm_guid']
    vm = $evm.vmdb(:vm).find_by_id(vm_search) || $evm.vmdb(:vm).find_by_guid(vm_search)
  end

  vm = $evm.root['vm'] if vm.nil?
  if vm && vm.service
    log(:info, "Found VM: #{vm.name} id: #{vm.id} guid: #{vm.guid}")
    log(:info, "Removing VM: #{vm.name} from service: #{vm.service.name}")
    vm.remove_from_service
  end

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
