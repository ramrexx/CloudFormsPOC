# list_disk_numbers.rb
#
# Description: List the disk numbers on a VM
#

# Get vm object from root
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" if vm.nil?

disks_hash = {'<choose>' => nil}

# get current number of hard drives
num_disks = vm.num_hard_disks

for disk_num in (1..num_disks)
  disk_size = "disk_#{disk_num}_size"
  if vm.respond_to?(disk_size)
    disks_hash[disk_num] = "disk#{disk_num}" unless vm.send(disk_size).to_i.zero?
  end
end

$evm.object['values'] = disks_hash
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")
