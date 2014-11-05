###################################
#
# CFME Automate Method: RunProgramInGuest_Linux
#
# Notes: This method will run a guest program with arguments on a Linux guest VM via VIX SDK/API.
#
# Requirements:
#   a) The latest VIX SDK can be downloaded from: http://www.vmware.com/support/developer/vix-api and must be installed on each CloudForms Appliance for this script to function
#   b) Guest VM must have VMware Tools running
#   c) Guest VM must already have the guest_program and it must be executable
#
# Model Inputs: vmrun_path, guest_username, guest_password
# Service Dialog Inputs: dialog_guest_program, dialog_guest_program_arguments
# Provisioning Inputs: prov.options.ws_values[:guest_program], prov.options.ws_values[:guest_program]
#
###################################
begin
  # Method for logging
  def log(level, message, update_message=false)
    @method = 'RunProgramInGuest_Linux'
    $evm.log(level, "#{@method} - #{message}")
    $evm.root['miq_provision'].message = "#{@method} - #{message}" if $evm.root['miq_provision'] && update_message
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
    log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  def stamp_vm(guest_program, guest_program_results)
    @vm.custom_set(:guest_program, guest_program.to_s)
    @vm.custom_set(:guest_program_results, guest_program_results.to_s)
  end

  # execute_vmrun
  def execute_vmrun(vmrun_command_parameter, guest_program=nil, guest_program_arguments=nil)
    require 'linux_admin'

    # Set vmrun below or get from model
    vmrun_path = nil
    vmrun_path ||= $evm.object['vmrun_path']
    raise "File '#{vmrun_path}' does not exist. Please install the VIX SDK..." unless File.exist?(vmrun_path)

    # setup credentials
    #guest_username = ".\\Administrator"
    guest_username = nil || $evm.object['guest_username']
    guest_password ||= $evm.object.decrypt('guest_password')
    authentication_flags = " -h https://#{@vm.ext_management_system.ipaddress}:443/sdk "
    authentication_flags += " -u \'#{@vm.ext_management_system.authentication_userid}\' "
    authentication_flags += " -p \'#{@vm.ext_management_system.authentication_password}\' "
    authentication_flags += " -gu \'#{guest_username}\' "
    authentication_flags += " -gp \'#{guest_password}\' "

    build_command = "#{vmrun_command_parameter}"
    build_command += " \'[#{@vm.storage_name}]#{@vm.location}\' "
    build_command += " \'#{guest_program}\' " unless guest_program.blank?
    if vmrun_command_parameter == 'runProgramInGuest'
      build_command += " \'#{guest_program_arguments} \'" unless guest_program_arguments.blank?
    end
    execute_command = vmrun_path + authentication_flags + build_command
    log(:info, "Executing #{vmrun_path} #{vmrun_command_parameter} with arguments #{build_command}", true)

    result = LinuxAdmin.run!(execute_command)
    log(:info, "result output: #{result.output.inspect} error: #{result.error.inspect} exit_status: #{result.exit_status.inspect}")
    return result
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root()

  case $evm.root['vmdb_object_type']
  when 'vm'
    @vm = $evm.root['vm']

    # look in root for dialog_guest_program and dialog_program_arguments coming from service dialog
    guest_program = $evm.root['dialog_guest_program']
    guest_program_arguments = $evm.root['dialog_guest_program_arguments']
  when 'miq_provision'
    prov = $evm.root['miq_provision']
    raise "miq_provision object not found" if prov.nil?
    log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")
    @vm = $evm.root['miq_provision'].vm
    prov_tags = prov.get_tags
    log(:info, "Inspecting miq_provision tags:<#{prov_tags.inspect}>")

    # look in ws_values for guest_program and guest_program_arguments for dynamic override
    ws_values = prov.options.fetch(:ws_values, nil)
    guest_program = ws_values.fetch(:guest_program, nil) unless ws_values.blank?
    guest_program_arguments = ws_values.fetch(:guest_program_arguments, nil) unless ws_values.blank?
    log(:info, "Found guest_program from prov.options[:ws_values]: #{guest_program.inspect}") unless guest_program.nil?
    log(:info, "Found guest_program_arguments from prov.options[:ws_values]: #{guest_program_arguments.inspect}") unless guest_program_arguments.nil?
  else
    log(:warn, "Invalid $evm.root['vmdb_object_type']: #{$evm.root['vmdb_object_type']}")
    exit MIQ_STOP
  end
  raise "VM object not found" if @vm.nil?
  # set guest_program and guest_program_arguments here else inherit from the instance
  guest_program ||= $evm.object['guest_program']
  guest_program_arguments ||= $evm.object['guest_program_arguments']

  # Get the VMs operating system product information
  log(:info, "Found VM: #{@vm.name} vendor: #{@vm.vendor} product: #{@vm.operating_system[:product_name].downcase}")

  # Bail unless linux and vmware
  unless @vm.operating_system[:product_name].downcase.include?('linux') && @vm.vendor.downcase == 'vmware'
    log(:warn, "Invalid vendor or product found")
    exit MIQ_STOP
  end

  # Since this is provisioning we need to put in retry logic to wait until IP Addresses are populated.
  unless @vm.ipaddresses.empty?
    non_zeroconf = false
    @vm.ipaddresses.each do |ipaddr|
      non_zeroconf = true unless ipaddr.match(/^(169.254|0)/)
      log(:info, "VM: #{@vm.name} IP Address found #{ipaddr} (#{non_zeroconf})")
    end
    if non_zeroconf
      log(:info, "VM: #{@vm.name} IP addresses: #{@vm.ipaddresses.inspect} present")
      $evm.root['ae_result'] = 'ok'
    else
      log(:warn, "VM:<#{@vm.name}> IP addresses: #{@vm.ipaddresses.inspect} not present")
      retry_method(1.minute)
    end
  else
    # bail out if we were executed from a button and the vm does not have an IP address
    unless $evm.root['vm'].nil?
      raise "VM: #{@vm.name} IP addresses: #{@vm.ipaddresses.inspect} not present"
    else
      log(:warn, "Provisionin VM: #{@vm.name} IP addresses: #{@vm.ipaddresses.inspect} not present")
      retry_method(1.minute)
    end
  end

  log(:info, "vm.name: #{@vm.name} vm.storage_name: #{@vm.storage_name} vm.location: #{@vm.location}")
  if @vm.storage_name.nil?
    log(:error, "vm.storage_name Missing - Retrying method")
    retry_method(1.minute)
  end

  # check to ensure that guest_program exists then execute it
  fileExistsInGuest_results = execute_vmrun('fileExistsInGuest', guest_program)

  if fileExistsInGuest_results.exit_status.zero?
    log(:info, "VMrun command fileExistsInGuest completed with results:<#{fileExistsInGuest_results}>")
    # Call runProgramInGuest method
    runProgramInGuest_results = execute_vmrun('runProgramInGuest', guest_program, guest_program_arguments)

    # set custom attributes on VM
    stamp_vm(guest_program, runProgramInGuest_results.exit_status)

    if runProgramInGuest_results.exit_status.zero?
      log(:info, "VMrun command runProgramInGuest completed with results:<#{runProgramInGuest_results}>", true)
    else
      log(:error, "VMrun command runProgramInGuest failed with results:<#{runProgramInGuest_results}>", true)
    end
  else
    log(:info, "VMrun command fileExistsInGuest failed with results:<#{fileExistsInGuest_results}>")
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
