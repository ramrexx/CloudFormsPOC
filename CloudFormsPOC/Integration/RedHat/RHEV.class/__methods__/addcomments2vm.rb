###################################
#
# CFME Automate Method: AddComments2VM
#
# Author: Kevin Morey
#
# Notes: This method updates the VM description in RHEVM and can either be called via a button or during provisioning
# - gem requirements 'rest_client'
#
# - Parameters for $evm.root['vmdb_object_type'] = 'vm'
#   - $evm.root['dialog_description']
#
# - Parameters for $evm.root['vmdb_object_type'] = 'miq_provision'
#   - prov.get_option(::vm_notes)
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'AddComments2VM'
    $evm.log(level, "#{@method} - #{message}")
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

  # call_rhevm
  def call_rhevm(action, body, vm)
    require 'rest_client'

    servername = vm.ext_management_system.ipaddress
    username = vm.ext_management_system.authentication_userid
    password = vm.ext_management_system.authentication_password

    log(:info, "Calling -> RHEVM:<#{servername}#{vm.ems_ref}> action:<#{action}> xml:#{body} VM:<#{vm.name}>")
    response = RestClient::Request.new(
      :method=>action,
      :url=>"https://#{servername}"+"#{vm.ems_ref}",
      :user=>username,
      :password=>password,
      :payload=>body,
      :headers=>{
        :accept=>'application/xml',
        :content_type=>'application/xml'
      }
    ).execute
    unless response.code == 200
      raise "Failure <- RHEVM Response:<#{response.code}>"
    else
      log(:info, "Success <- RHEVM Response:<#{response.code}>")
    end
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  case $evm.root['vmdb_object_type']

  when 'miq_provision'
    prov = $evm.root['miq_provision']
    log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

    # get vm object from miq_provision. This assumes that the vm container on the management system is present
    vm = prov.vm

    # Since this is provisioning we need to put in retry logic to wait the vm is present
    if vm.nil?
      log(:warn, "$evm.root['miq_provision'].vm not present.")
      retry_method()
    end

    unless prov.get_option(:vm_notes).nil?
      description = prov.get_option(:vm_notes)
    else
      # Setup VM Notes & Annotations
      description =  "Owner: #{prov.get_option(:owner_first_name)} #{prov.get_option(:owner_last_name)}"
      description += "\nEmail: #{prov.get_option(:owner_email)}"
      description += "\nSource Template: #{template.name}"
      description += "\nCustom Description: #{prov.get_option(:vm_description)}" unless prov.get_option(:vm_description).nil?
    end

  when 'vm'
    # get vm from root
    vm = $evm.root['vm']

    # get description from button/service dialog
    description = $evm.root['dialog_description']
  else
    raise "Invalid $evm.root['vmdb_object_type']:<#{$evm.root['vmdb_object_type']}>. Skipping method."
  end

  log(:info, "Found VM:<#{vm.name}> vendor:<#{vm.vendor.downcase}>")
  if vm.vendor.downcase == 'redhat'
    # Call rhevm to set the VMs description
    body="<vm><description>#{description}</description></vm>"
    call_rhevm(:put, body, vm)
  else
    raise "Invalid vendor:<#{vm.vendor.downcase}>. Skipping method"
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
