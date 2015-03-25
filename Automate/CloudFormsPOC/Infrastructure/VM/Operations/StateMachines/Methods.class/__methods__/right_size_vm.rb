# right_size_vm.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method reconfigures the VM based on right size recommendations
#
category = :rightsize

vm = $evm.root['vm']
raise "VM not found" if vm.nil?
$evm.log(:info, "Found VM: #{vm.name} tags: #{vm.tags} vCPUS: #{vm.num_cpu} vRAM: #{vm.mem_cpu}")

rightsizing = vm.tags(category).first rescue nil
raise "VM: #{vm.name} is not tagged with #{category}" if rightsizing.nil?

case rightsizing
when 'aggressive'
  recommended_cpu = vm.aggressive_recommended_vcpus.to_i
  recommended_mem = vm.aggressive_recommended_mem.to_i
when 'moderate'
  recommended_cpu = vm.moderate_recommended_vcpus.to_i
  recommended_mem = vm.moderate_recommended_mem.to_i
when 'conservative'
  recommended_cpu = vm.conservative_recommended_vcpus.to_i
  recommended_mem = vm.conservative_recommended_mem.to_i
else
  raise "Missing rightsizing tag: #{rightsizing}"
end

unless recommended_cpu.zero?
  $evm.log(:info, "VM: #{vm.name} rightsizing: #{rightsizing} vCPUs: #{recommended_cpu}")
  vm.object_send('instance_eval', "with_provider_object { | vimVm | vimVm.setNumCPUs(#{recommended_cpu}) }")
end

unless recommended_mem.zero?
  $evm.log(:info, "VM: #{vm.name} rightsizing: #{rightsizing} vRAM: #{recommended_mem}")
  vm.object_send('instance_eval', "with_provider_object { | vimVm | vimVm.setMemory(#{recommended_mem}) }")
end
