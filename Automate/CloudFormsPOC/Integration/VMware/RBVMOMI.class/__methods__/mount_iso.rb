###################################
#
# CFME Automate Method: Mount_ISO
#
# Notes: This is a template for creating new methods
#
# Inputs:
#
###################################
begin
  # Method for logging
  def log(level, msg, update_message=false)
    @method = 'Mount_ISO'
    $evm.log(level, "#{@method} - #{msg}")
    $evm.root['miq_provision'].message = "#{@method} - #{msg}" if $evm.root['miq_provision'] && update_message
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # basic retry logic
  def retry_method(retry_time=1.minute)
    #log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  def mount_iso(provider, vm, iso_file)
    begin
      gem 'nokogiri', '=1.5.5'
      require 'rbvmomi'
    rescue LoadError
      log(:error, "pkg requirements: yum install -y gcc ruby193-ruby-devel libxml2 libxml2-devel libxslt libxslt-devel")
      log(:error, "gem requirements: gem install rbvmomi | gem install nokogiri -v 1.5.5")
      return false
    end
    credentials = {
      :host => nil || provider.ipaddress,
      :user => nil || provider.authentication_userid,
      :password => nil || provider.authentication_password,
      :insecure => true
    }

    log(:info, "Logging in to #{credentials[:host]}....", true)
    vim = RbVmomi::VIM.connect credentials
    log(:info, "Login successful to #{credentials[:host]}", true)

    log(:info, "Looking for datacenter object: #{vm.v_owning_datacenter}", true)
    dc = vim.serviceInstance.find_datacenter("#{vm.v_owning_datacenter}")
    log(:info, "Found datacenter object: #{dc.inspect}", true)

    log(:info, "Looking for current_vm_folder object: #{vm.v_owning_blue_folder}", true)
    current_vm_folder = dc.vmFolder.traverse("#{vm.v_owning_blue_folder}", RbVmomi::VIM::Folder, false)
    log(:info, "Found current_vm_folder object: #{current_vm_folder}", true)

    log(:info, "Looking for VM: #{vm.name} object", true)
    vsphere_vm = current_vm_folder.childEntity.grep(RbVmomi::VIM::VirtualMachine).find { |x| x.name == vm.name } or fail "VM: #{vm.name} not found"
    log(:info, "Found VM: #{vm.name} object", true)

    log(:info, "Looking for cdrom object")
    cdrom = vsphere_vm.config.hardware.device.select {|hw| hw.class == RbVmomi::VIM::VirtualCdrom }.first
    log(:info, "Found cdrom object: #{cdrom.inspect}")

    log(:info, "Mounting ISO: #{iso_file} on VM: #{vm.name}", true)
    machine_conf_spec = RbVmomi::VIM::VirtualMachineConfigSpec(
      deviceChange: [{
                       operation: :edit,
                       device: RbVmomi::VIM::VirtualCdrom(
                         backing: RbVmomi::VIM::VirtualCdromIsoBackingInfo(:fileName => iso_file ),
                         key: cdrom.key,
                         controllerKey: cdrom.controllerKey,
                         connectable: RbVmomi::VIM::VirtualDeviceConnectInfo(:startConnected => true, :connected => false, :allowGuestControl => true)
    )}])
    vsphere_vm.ReconfigVM_Task(spec: machine_conf_spec).wait_for_completion
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root()

  case $evm.root['vmdb_object_type']
  when 'miq_provision'
    prov = $evm.root['miq_provision']
    log(:info, "Provision: #{prov.id} Request: #{prov.miq_provision_request.id} Type: #{prov.type}")
    vm          = prov.vm
    provider    = vm.ext_management_system
  when 'vm'
    vm          = $evm.root['vm']
    provider    = vm.ext_management_system
    iso_file    = $evm.root['dialog_iso_file']
  end
  log(:info, "VM: #{vm.name} vendor: #{vm.vendor} provider: #{provider.name} datacenter: #{vm.v_owning_datacenter} iso_file: #{iso_file}")

  if vm.vendor.downcase == 'vmware'
    mount_iso(provider, vm, iso_file)
    vm.custom_set(:CDROM, iso_file.to_s)
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
