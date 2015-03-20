# list_openstack_flavors_for_vm.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: List available OpenStack flavor ids for a particular instance's provider
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
  vm = $evm.root['vm']
  vm_flavor_id = vm.flavor.id

  dialog_hash = {}
  provider = vm.ext_management_system

  provider.flavors.each do |fl|
    log(:info, "Looking at flavor: #{fl.name} id: #{fl.id} cpus: #{fl.cpus} memory: #{fl.memory} ems_ref: #{fl.ems_ref}")
    next unless fl.ext_management_system || fl.enabled
    if fl.id == vm_flavor_id
      dialog_hash[nil] = "<Current - #{fl.name}>"
    else
      dialog_hash[fl.id] = "#{fl.name}"
    end
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
