###################################
#
# CFME Automate Method: CreateIncident
#
# Author: Kevin Morey
#
# Notes: This method uses a SOAP/XML call to create a ServiceNow Incident for host or vm
#
# Notes:
# - Gem requirements: savon -v 1.1.0
# - Inputs: $evm.root['vmdb_object_type'] = 'vm' || 'host'
# - Parms: $evm.root['dialog_miq_alert_description'] (optional)
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'CreateIncident'
    $evm.log(level, "#{@method} - #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # Method: call_servicenow
  def call_servicenow(soap_action, body_hash)
    # Require Savon Ruby Gem
    gem 'savon', '=1.1.0'
    require "savon"
    require 'httpi'

    # Configure HTTPI gem
    HTTPI.log_level = :info # changing the log level
    HTTPI.log       = false # diable HTTPI logging
    HTTPI.adapter   = :net_http # [:httpclient, :curb, :net_http]

    # Configure Savon gem
    Savon.configure do |config|
      config.log        = false      # disable Savon logging
      config.log_level  = :fatal      # changing the log level
    end

    servername = nil
    servername ||= $evm.object['servername']
    username = nil
    username ||= $evm.object['username']
    password = nil
    password ||= $evm.object.decrypt('password')

    # Set up SOAP Connection to WSDL
    client = Savon::Client.new do |wsdl,http|
      wsdl.document = "https://#{servername}/incident.do?WSDL"
      http.auth.basic username, password
    end

    log(:info, "Namespace: #{client.wsdl.namespace} Endpoint: #{client.wsdl.endpoint} Actions: #{client.wsdl.soap_actions}")

    log(:info, "Calling ServiceNow: #{servername} soap_action: #{soap_action}  with parameters: #{body_hash.inspect}")
    # Actions: - :insert, :update, :delete_multiple, :get_keys, :delete_record, :get, :get_records
    response = client.request soap_action do |soap|
      soap.body = body_hash
    end
    log(:info, "ServiceNow Response: #{response.to_hash.inspect}")
    # Convert xml response to a hash
    return response.to_hash["#{soap_action}_response".to_sym]
  end

  # create_vm_incident
  def create_vm_incident(vm)
    # object_name = 'Event' means that we were triggered from an Alert
    if $evm.root['object_name'] == 'Event'
      log(:info, "Detected Alert driven event")
      (body_hash ||= {})['short_description'] = "VM: #{vm.name} - #{$evm.root['miq_alert_description']}"
    elsif $evm.root['ems_event']
      # ems_event means that were triggered via Control Policy
      log(:info, "Detected Policy driven event")
      log(:info, "Inspecting $evm.root['ems_event']:<#{$evm.root['ems_event'].inspect}>")
      (body_hash ||= {})['short_description'] = "VM: #{vm.name} - #{$evm.root['ems_event'].event_type}"
    else
      unless $evm.root['dialog_miq_alert_description'].nil?
        log(:info, "Detected service dialog driven event")
        # If manual creation add dialog input notes to body_hash
        (body_hash ||= {})['short_description'] = "VM: #{vm.name} - #{$evm.root['dialog_miq_alert_description']}"
      else
        log(:info, "Detected manual driven event")
        # If manual creation add default notes to body_hash
        (body_hash ||= {})['short_description'] = "VM: #{vm.name} - Incident manually created"
      end
    end
    comments = "VM: #{vm.name}\n"
    comments += "Hostname: #{vm.hostnames.first}\n" unless vm.hostnames.nil?
    comments += "Guest OS Description: #{vm.hardware.guest_os_full_name.inspect}\n" unless vm.hardware.guest_os_full_name.nil?
    comments += "IP Address: #{vm.ipaddresses}\n"
    comments += "Provider: #{vm.ext_management_system.name}\n" unless vm.ext_management_system.nil?
    comments += "Cluster: #{vm.ems_cluster.name}\n" unless vm.ems_cluster.nil?
    comments += "Host: #{vm.host.name}\n" unless vm.host.nil?
    comments += "CloudForms: #{$evm.root['miq_server'].hostname}\n"
    comments += "Region Number: #{vm.region_number}\n"
    comments += "vCPU: #{vm.num_cpu}\n"
    comments += "vRAM: #{vm.mem_cpu}\n"
    comments += "Disks: #{vm.num_disks}\n"
    comments += "Power State: #{vm.power_state}\n"
    comments += "Storage Name: #{vm.storage_name}\n"
    comments += "Allocated Storage: #{vm.allocated_disk_storage}\n"
    comments += "Provisioned Storage: #{vm.provisioned_storage}\n"
    comments += "GUID: #{vm.guid}\n"
    comments += "Tags: #{vm.tags.inspect}\n"
    body_hash['comments'] = comments

    log(:info, "VM: #{vm.name} - incident information: #{body_hash.inspect}")
    servicenow_response = call_servicenow(:insert, body_hash)

    log(:info, "Adding custom attribute :servicenow_incident_number => #{servicenow_response[:number]} to VM: #{vm.name}")
    vm.custom_set(:servicenow_incident_number, servicenow_response[:number].to_s)
    log(:info, "Adding custom attribute :servicenow_incident_sysid => #{servicenow_response[:sys_id]}> to VM: #{vm.name}")
    vm.custom_set(:servicenow_incident_sysid, servicenow_response[:sys_id].to_s)
  end

  # create_host_incident
  def create_host_incident(host)
    if $evm.root['object_name'] == 'Event'
      log(:info, "Detected Alert driven event")
      (body_hash ||= {})['short_description'] = "Host: #{host.name} - #{$evm.root['miq_alert_description']}"
    elsif $evm.root['ems_event']
      # ems_event means that were triggered via Control Policy
      log(:info, "Detected Policy driven event")
      log(:info, "Inspecting $evm.root['ems_event']:<#{$evm.root['ems_event'].inspect}>")
      (body_hash ||= {})['short_description'] = "Host: #{host.name} - #{$evm.root['ems_event'].event_type}"
    else
      unless $evm.root['dialog_miq_alert_description'].nil?
        log(:info, "Detected service dialog driven event")
        # If manual creation add dialog input notes to body_hash
        (body_hash ||= {})['short_description'] = "Host: #{host.name} - #{$evm.root['dialog_miq_alert_description']}"
      else
        log(:info, "Detected manual driven event")
        # If manual creation add default notes to body_hash
        (body_hash ||= {})['short_description'] = "Host: #{host.name} - Incident manually created"
      end
    end
    # Build information about the Host
    comments = "Host: #{host.name}\n"
    comments += "Hostname: #{host.hostname}\n" unless host.hostname.nil?
    comments += "Guest OS Description: #{host.hardware.guest_os_full_name.inspect}\n" unless host.hardware.guest_os_full_name.nil?
    comments += "IP Address: #{host.ipaddress}\n"
    comments += "IPMI Address: #{host.ipmi_address}\n"
    comments += "Provider: #{host.ext_management_system.name}\n" unless host.ext_management_system.nil?
    comments += "Cluster: #{host.ems_cluster.name || nil}\n" unless host.ems_cluster.nil?
    comments += "CloudForms: #{$evm.root['miq_server'].hostname}\n"
    comments += "Region Number: #{host.region_number}\n"
    comments += "vCPU: #{host.hardware.numvcpus || 0}\n" unless host.hardware.nil?
    comments += "vRAM: #{host.hardware.memory_cpu || 0}\n" unless host.hardware.nil?
    comments += "Asset Tag: #{host.asset_tag}\n"
    comments += "Service Tag: #{host.service_tag}\n"
    comments += "Power State: #{host.power_state}\n"
    comments += "CPU Usage: #{host.hardware.cpu_usage}\n" unless host.hardware.nil?
    comments += "Memory Usage: #{host.hardware.memory_usage}\n" unless host.hardware.nil?
    comments += "VMs: #{host.vms.count}\n" unless host.vms.nil?
    comments += "GUID: #{host.guid}\n"
    comments += "Tags: #{host.tags.inspect}\n" unless host.tags.nil?
    body_hash['comments'] = comments

    log(:info, "host:<#{host.name}> - incident information:<#{body_hash.inspect}>")
    servicenow_response = call_servicenow(:insert, body_hash)

    log(:info, "Adding custom attribute :servicenow_incident_number => #{servicenow_response[:number]} to Host: #{host.name}")
    host.custom_set(:servicenow_incident_number, servicenow_response[:number].to_s)
    log(:info, "Adding custom attribute :servicenow_incident_sysid => #{servicenow_response[:sys_id]} to Host: #{host.name}")
    host.custom_set(:servicenow_incident_sysid, servicenow_response[:sys_id].to_s)
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  case $evm.root['vmdb_object_type']
  when 'vm';   create_vm_incident($evm.root[$evm.root['vmdb_object_type']])
  when 'host'; create_host_incident($evm.root[$evm.root['vmdb_object_type']])
  else
    log(:warn, "Invalid $evm.root['vmdb_object_type']:<#{$evm.root['vmdb_object_type']}>")
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
