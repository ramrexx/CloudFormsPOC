# AddRAM_to_VM.rb
# 
# Description: This method is used to modify vRAM to an existing VM running on VMware
#

# Get vm object from root
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" if vm.nil?

# if dialog_ram then we are adding ram
ram = $evm.root['dialog_ram'].to_i

unless ram.zero?
  $evm.log(:info, "Adding #{ram} MB to VM: #{vm.name} current memory: #{vm.mem_cpu}")
  ram += vm.mem_cpu 
end

ram = $evm.root['dialog_vm_memory'].to_i if ram.zero?

unless ram.zero?
  $evm.log(:info, "Setting VM: #{vm.name} vRAM to: #{ram}")
  vm.set_memory(ram, :sync => true)
end
