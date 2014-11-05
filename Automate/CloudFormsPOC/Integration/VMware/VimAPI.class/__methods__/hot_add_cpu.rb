# hot_add_cpu.rb
# Kevin Morey
# Description: This method is used to modify vCPUs to an existing VM running on VMware

# Get vm object from root
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" unless vm.nil?

# Check to ensure that the VM in question is vmware
vendor = vm.vendor.downcase rescue nil
raise "Invalid vendor detected: #{vendor}" unless vendor == 'vmware'

# Get the number of cpus from root
cores_per_socket = $evm.root['dialog_cpus'] || $evm.root['dialog_cores_per_socket']
log(:info, "Detected cores_per_socket: #{cores_per_socket}")

# Add cpus to VM
unless cores_per_socket.to_i.zero?
  $evm.log(:info, "Setting number of vCPUs to #{cores_per_socket} on VM: #{vm.name}")
  vm.set_number_of_cpus(cores_per_socket.to_i, :sync=>true)
end
