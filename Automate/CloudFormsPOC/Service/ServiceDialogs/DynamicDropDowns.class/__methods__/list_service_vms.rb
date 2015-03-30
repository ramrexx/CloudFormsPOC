# list_service_vms.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method will build a list of vms attached to a service
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
  log(:info, "Service: #{service.name} id: #{service.id} guid: #{service.guid} vms: #{service.vms.count}")

  dialog_hash = {}

  service.vms.each do |vm|
    dialog_hash[vm.id] = "#{vm.name} on #{service.name}"
  end

  if dialog_hash.blank?
    log(:info, "No VMs found")
    dialog_hash[nil] = "< No VMs found >"
  else
    dialog_hash[nil] = '< choose a VM >'
  end

  $evm.object["values"]     = dialog_hash
  log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")

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
