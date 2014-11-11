# ResizeDisk.rb
#
# Description: This method is used to increase the size of a VMWare VMs disk
#

def resizeDisk(vm, disk_number, new_disk_size_in_kb)
  $evm.log(:info, "Doing object_send")

  vm.object_send('instance_eval', '
      def do_stuff(myevm, diskIndex, new_disk_size_in_kb)
        myevm.log("info", "VMware_HotResize_Disk - test")
        devs = nil
        with_provider_object{ |vimVm| 
          devs = vimVm.send(:getProp, "config.hardware")["config"]["hardware"]["device"]
          myevm.log("info", "VMware_HotResize_Disk: #{devs.inspect}")
        }
        matchedDev = nil
        currentDiskIndex = 0
        myevm.log("info", "VMWare_HotResize_Disk: looking for disk at index #{diskIndex}")
        devs.each do | dev |
          myevm.log("info", "VMWare_HotResize_Disk: testing dev #{dev.xsiType} #{dev.inspect}")
          next if dev.xsiType != "VirtualDisk"
          myevm.log("info", "VMWare_HotResize_Disk: disk #{dev.inspect}")
          if diskIndex == currentDiskIndex
            matchedDev = dev
            break
          end
          currentDiskIndex += 1
        end
      
        myevm.log("info", "VMware_HotResize_Disk Matched Dev #{matchedDev.inspect}")
        currentSizeKB = matchedDev["capacityInKB"].to_i
        myevm.log("info", "VMware_HotResize_Disk: Current Size #{currentSizeKB}")
        myevm.log("info", "VMware_HotResize_Disk: Requested Size #{new_disk_size_in_kb}")
        raise "resizeDisk: disk #{diskIndex} not found" unless matchedDev
        raise "cannot shrink disk #{matchedDev} to #{new_disk_size_in_kb}" if currentSizeKB > new_disk_size_in_kb.to_i

        vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
          vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
            vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
              vdcs.operation = "edit".freeze
              vdcs.device    = VimHash.new("VirtualDisk") do |vDev|
                vDev.key           = matchedDev["key"]
                vDev.controllerKey = matchedDev["controllerKey"]
                vDev.unitNumber    = matchedDev["unitNumber"]
                vDev.backing       = matchedDev["backing"]
                vDev.capacityInKB  = new_disk_size_in_kb
              end
            end
          end
        end
        myevm.log("info", "VMware_HotResize_Disk #{vmConfigSpec.inspect}")
        with_provider_object {|vimVm| vimVm.send(:reconfig, vmConfigSpec) }
        myevm.log("info", "VMware_HotResize_Disk Sent Reconfigure Successfully")
      end')
  begin
    vm.object_send('do_stuff', $evm, disk_number, new_disk_size_in_kb)
  rescue => myerr
    $evm.log(:error, "Error occurred communicating with vSphere API: #{myerr.class} #{myerr} #{myerr.backtrace.join("\n")}")
    exit MIQ_STOP
  end
end

# Get vm object from root
vm = $evm.root['vm']
raise "VM object not found" if vm.nil?

# This method only works with VMware VMs currently
raise "Invalid vendor:<#{vm.vendor}>" unless vm.vendor.downcase == 'vmware'

# Get dialog_disk_number variable from root hash if nil convert to zero
disk_number = $evm.root['dialog_disk_number'].to_i
raise "Invalid Disk Number: #{disk_number}" if disk_number.zero?

# Get dialog_size variable from root hash if nil convert to zero
size = $evm.root['dialog_size'].to_i

$evm.log(:info,"Detected VM:<#{vm.name}> vendor:<#{vm.vendor}> disk_number:<#{disk_number.inspect}> size:<#{size.inspect}>")

new_disk_size_in_kb = size * (1024**2)
$evm.log(:info, "New size in KB: #{new_disk_size_in_kb}")

unless size.zero?
  $evm.log(:info,"VM:<#{vm.name}> Increasing Disk #{disk_number} size to #{new_disk_size_in_kb / 1024**2}GB")

  # Subtract 1 from the disk_number since VMware starts at 0 and CFME start at 1
  disk_number -= 1
  resizeDisk(vm, disk_number, new_disk_size_in_kb)
end
