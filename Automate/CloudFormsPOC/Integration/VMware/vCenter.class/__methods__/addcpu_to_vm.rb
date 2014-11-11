# AddCPU_to_VM.rb
# 
# Description: This method is used to modify vCPUs to an existing VM running on VMware
#

# Get vm object from root
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" if vm.nil?

# Check to ensure that the VM in question is vmware
vendor = vm.vendor.downcase rescue nil
raise "Invalid vendor detected: #{vendor}" unless vendor == 'vmware'

# if dialog_cpus then we are adding cpus
vcpus = $evm.root['dialog_cpus'].to_i

unless vcpus.zero?
  $evm.log(:info, "Adding #{vcpus} vCPU(s) to VM: #{vm.name} current vCPU count: #{vm.num_cpu}")
  vcpus += vm.num_cpu 
end

vcpus = $evm.root['dialog_cores_per_socket'].to_i if vcpus.zero?

unless vcpus.zero?
  $evm.log(:info, "Setting VM: #{vm.name} vCPU count to: #{vcpus}")
  vm.set_number_of_cpus(vcpus, :sync=>true)
end
