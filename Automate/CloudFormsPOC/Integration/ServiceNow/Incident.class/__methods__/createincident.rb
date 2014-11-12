###################################
#
# CreateIncident
#
# Description: This method uses a SOAP/XML call to create a ServiceNow Incident for host or vm
#
require "savon"

# Method: call_servicenow
def servicenow_client(ref)
  servername = nil
  servername ||= $evm.object['servername']
  username = nil
  username ||= $evm.object['username']
  password = nil
  password ||= $evm.object.decrypt('password')

  # if ref is a url then use that one instead
  unless ref.nil?
    wsdl = ref if ref.include?('http')
  end
  wsdl ||= "https://#{servername}"+"#{ref}"

  client = Savon.client(
    :wsdl => "https://#{servername}#{ref}",
    :basic_auth => [username, password],
    :ssl_verify_mode => :none,
    :ssl_version => :TLSv1,
    :raise_errors => false,
    :log_level => :info,
    :log => false
  )
  #client.operations.sort.each { |operation| $evm.log(:info, "Savon Operation: #{operation}") }
  return client
end

# create_vm_incident
def build_vm_body(vm)
  comments = "VM: #{vm.name}\n"
  comments += "Hostname: #{vm.hostnames.first}\n" unless vm.hostnames.nil?
  comments += "Guest OS Description: #{vm.hardware.guest_os_full_name.inspect}\n" unless vm.hardware.guest_os_full_name.nil?
  comments += "IP Address: #{vm.ipaddresses}\n"
  comments += "Provider: #{vm.ext_management_system.name}\n" unless vm.ext_management_system.nil?
  comments += "Cluster: #{vm.ems_cluster.name}\n" unless vm.ems_cluster.nil?
  comments += "Host: #{vm.host.name}\n" unless vm.host.nil?
  comments += "CloudForms Server: #{$evm.root['miq_server'].hostname}\n"
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
  (body_hash ||= {})['comments'] = comments
  return body_hash
end

# create_host_incident
def build_host_body(host)
  # Build information about the Host
  comments = "Host: #{host.name}\n"
  comments += "Hostname: #{host.hostname}\n" unless host.hostname.nil?
  comments += "Guest OS Description: #{host.hardware.guest_os_full_name.inspect}\n" unless host.hardware.guest_os_full_name.nil?
  comments += "IP Address: #{host.ipaddress}\n"
  comments += "IPMI Address: #{host.ipmi_address}\n"
  comments += "Provider: #{host.ext_management_system.name}\n" unless host.ext_management_system.nil?
  comments += "Cluster: #{host.ems_cluster.name || nil}\n" unless host.ems_cluster.nil?
  comments += "CloudForms Server: #{$evm.root['miq_server'].hostname}\n"
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
  (body_hash ||= {})['comments'] = comments
  return body_hash
end

$evm.root.attributes.sort.each { |k, v| $evm.log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

object = $evm.root[$evm.root['vmdb_object_type']]

case $evm.root['vmdb_object_type']
when 'vm'
  body_hash = build_vm_body(object)
when 'host'
  body_hash = build_host_body(object)
else
  raise "Invalid $evm.root['vmdb_object_type']: #{object}"
end

unless body_hash.nil?
  # object_name = 'Event' means that we were triggered from an Alert
  if $evm.root['object_name'] == 'Event'
    $evm.log(:info, "Detected Alert driven event")
    body_hash['short_description'] = "#{$evm.root['vmdb_object_type']}: #{object.name} - #{$evm.root['miq_alert_description']}"
  elsif $evm.root['ems_event']
    # ems_event means that were triggered via Control Policy
    $evm.log(:info, "Detected Policy driven event")
    $evm.log(:info, "Inspecting $evm.root['ems_event']:<#{$evm.root['ems_event'].inspect}>")
    body_hash['short_description'] = "#{$evm.root['vmdb_object_type']}: #{object.name} - #{$evm.root['ems_event'].event_type}"
  else
    unless $evm.root['dialog_miq_alert_description'].nil?
      $evm.log(:info, "Detected service dialog driven event")
      # If manual creation add dialog input notes to body_hash
      body_hash['short_description'] = "#{$evm.root['vmdb_object_type']}: #{object.name} - #{$evm.root['dialog_miq_alert_description']}"
    else
      $evm.log(:info, "Detected manual driven event")
      # If manual creation add default notes to body_hash
      body_hash['short_description'] = "#{$evm.root['vmdb_object_type']}: #{object.name} - Incident manually created"
    end
  end

  # call servicenow
  $evm.log(:info, "Calling ServiceNow: incident information: #{body_hash.inspect}")
  insert_incident_result = servicenow_client('/incident.do?WSDL').call(:insert) do
    message(  body_hash ).to_hash
  end
  #$evm.log(:info, "insert_incident_result: #{insert_incident_result.inspect}")
  $evm.log(:info, "insert_incident_result: #{insert_incident_result.body.inspect}")
  $evm.log(:info, "insert_incident_result success?: #{insert_incident_result.success?}")

  servicenow_response = insert_incident_result.body[:insert_response]
  #:insert_response=>{:sys_id=>"212a4e820f9071003bcf1d3be1050e9f", :number=>"INC0010001"}}

  $evm.log(:info, "Adding custom attribute :servicenow_incident_number => #{servicenow_response[:number]} to #{$evm.root['vmdb_object_type']}: #{object.name}")
  object.custom_set(:servicenow_incident_number, servicenow_response[:number].to_s)
  $evm.log(:info, "Adding custom attribute :servicenow_incident_sysid => #{servicenow_response[:sys_id]}> to #{$evm.root['vmdb_object_type']}: #{object.name}")
  object.custom_set(:servicenow_incident_sysid, servicenow_response[:sys_id].to_s)
end
