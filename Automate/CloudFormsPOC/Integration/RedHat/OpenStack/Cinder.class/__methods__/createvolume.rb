# createVolume.rb
#
# Description: create a volume in OpenStack
#
require 'fog'

def log(level, msg, update_message=false)
  $evm.log(level,"#{msg}")
  $evm.root['service_template_provision_task'].message = msg if $evm.root['service_template_provision_task'] && update_message
end

def get_tenant
  tenant_ems_id = $evm.root['dialog_cloud_tenant']
  log(:info, "Found EMS ID of tenant from dialog: #{tenant_ems_id}")
  return tenant_ems_id if tenant_ems_id.nil?

  tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
  log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
  return tenant
end


$evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

service_template_provision_task = $evm.root['service_template_provision_task']
service = service_template_provision_task.destination
log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")

boot_from_volume = $evm.root['dialog_boot_from_volume']
if boot_from_volume =~ (/(false|f|no|n|0)$/i)
  log(:warn, "boot_from_volume: #{boot_from_volume}. Skipping method.")
  exit MIQ_STOP
end

mid = $evm.root['dialog_mid']
raise "Management System ID is nil" if mid.blank?
openstack = nil

unless mid.blank?
  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
else
  openstack = $evm.vmdb(:ems_openstack).all.first
end
raise "OpenStack Management system with id '#{mid}' not found" if openstack.nil?
log(:info, "EMS_Openstack: #{openstack.inspect}\n#{openstack.methods.sort.inspect}")

unless $evm.root['dialog_instance_name'].nil?
  name = $evm.root['dialog_instance_name'] + 'vol1'
else
  name = $evm.root['dialog_volume_name'] || 'vol1'
end
description = "Volume #{name} created by CloudForms at #{Time.now}"
size = $evm.root['dialog_size'].to_i

tenant = get_tenant
log(:info, "Using tenant: #{tenant.name}")

conn = Fog::Volume.new(
  {
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant.name
})

log(:info, "Successfully connected to Storage Service at #{openstack.name}")
log(:info, "Creating volume #{name}/#{description} of size #{size}GB")

imageref = $evm.root['dialog_imageref']
volume = nil
if imageref.blank?
  volume = conn.create_volume(name, description, size).body['volume']
else
  log(:info, "Cloning image from image #{imageref}")
  volume = conn.create_volume(name, description, size, { :bootable => true, :imageRef => imageref }).body["volume"]
end

log(:info, "Create Volume Response: #{volume.inspect}")

service.name = "VOLUME: #{name} #{size}GB" if $evm.root['dialog_service_name'].nil?
service.description = "Cinder Volume with ID #{volume['id']} of size #{size}GB" if $evm.root['dialog_service_description'].nil?
service.custom_set("VOLUME_ID", "#{volume['id']}")
service.custom_set("MID", mid)
service.custom_set("IMAGEREF", "#{imageref}") unless imageref.blank?
service_template_provision_task.set_option(:volume_id, volume['id'])
service_template_provision_task.set_option(:mid, mid)
service_template_provision_task.set_option(:tenant_name, tenant.name)
service.tag_assign("cloud_tenants/#{tenant.name}")

log(:info, "Created #{service.name}/#{service.description}")
log(:info, "DETAILS: #{service_template_provision_task.inspect}")
