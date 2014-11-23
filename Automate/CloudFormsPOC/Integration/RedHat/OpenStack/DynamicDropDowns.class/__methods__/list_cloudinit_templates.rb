# list_cloudinit_templates.rb
#
# Description: list cloud-init customization templates
#

list = $evm.vmdb(:customization_template).all
$evm.log(:info, "Got list #{list.inspect}")
my_hash = {}
for ct in list
  if ct.name.start_with?("CLOUDINIT-OPENSTACK")
    my_hash[ct.id] = ct.description
    $evm.log(:info, "Pushed #{ct.name} onto the list")
  else
    $evm.log(:info, "Not pushing #{ct.name} onto the list")
  end
end

my_hash[nil] = nil
$evm.object['values'] = my_hash
$evm.log(:info, "Dynamic drop down values: #{$evm.object['values']}")
