# vmware_generate_mac_address.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method generates a mac address for PXE Enabled clients on VMware
#
def log_and_update_message(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  @task.message = msg if @task && (update_message || level == 'error')
end

def generate_unique_macaddress(nic_prefix)
  # Check up to 50 times for the existence of a randomly generated mac address
  for i in (1..50)
    new_macaddress = "#{nic_prefix}"+"#{("%02X" % rand(0x3F)).downcase}:#{("%02X" % rand(0xFF)).downcase}:#{("%02X" % rand(0xFF)).downcase}"
    log_and_update_message(:info, "Attempt #{i} - Checking for existence of mac_address: #{new_macaddress}")
    vm = $evm.vmdb('vm').all.detect {|v| v.mac_addresses.include?(new_macaddress)}
    return new_macaddress if vm.nil?
  end
end

begin

  nic_prefix = '00:50:56:'

  case $evm.root['vmdb_object_type']
  when 'miq_provision'
    # Get provisioning object
    prov = $evm.root["miq_provision"]
    log_and_update_message(:info, "Provision: #{prov.id} Request: #{prov.miq_provision_request.id} Type: #{prov.type}")

    if prov.type == 'MiqProvisionVmwareViaPxe'
      macaddress = generate_unique_macaddress(nic_prefix)
      #prov.set_network_adapter(0, {:mac_address => macaddress})
      prov.set_option(:mac_address, macaddress)
      log_and_update_message(:info, "Provisioning object updated {:mac_address => #{prov.get_option(:mac_address).inspect}}", true)
    end

    # if prov.type == 'MiqProvisionVmware'
    #   macaddress = generate_unique_macaddress(nic_prefix)
    #   #prov.set_network_adapter(0, {:mac_address => macaddress})
    #   prov.set_option(:mac_address, macaddress)
    #   log_and_update_message(:info, "Provisioning object updated {:mac_address => #{prov.get_option(:mac_address).inspect}}", true)
    # end

  when 'vm'
    vm = $evm.root['vm']
    log_and_update_message(:info, "VM: #{vm.name} mac_addresses: #{vm.mac_addresses}")
    macaddress = generate_unique_macaddress(nic_prefix)
    raise if macaddress.nil?
    log_and_update_message(:info, "Found available macaddress: #{macaddress}")
  end

rescue => err
  log_and_update_message(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
