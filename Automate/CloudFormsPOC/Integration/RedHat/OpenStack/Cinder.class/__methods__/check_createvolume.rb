# check_createVolume.rb
#
# Description: check creation of a volume in OpenStack
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

# basic retry logic
def retry_method(retry_time, msg)
  log(:info, "#{msg} - Waiting #{retry_time} seconds}", true)
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

$evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

service_template_provision_task = $evm.root['service_template_provision_task']
service = service_template_provision_task.destination
log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")

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

tenant = get_tenant
log(:info, "Using tenant: #{tenant.name}", true)

conn = Fog::Volume.new({
                         :provider => 'OpenStack',
                         :openstack_api_key => openstack.authentication_password,
                         :openstack_username => openstack.authentication_userid,
                         :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
                         :openstack_tenant => tenant.name
})

log(:info, "Successfully connected to Storage Service at #{openstack.name}", true)

volume_id = service_template_provision_task.get_option(:volume_id)
details = conn.get_volume_details(volume_id).body['volume']

status = details['status']
log(:info, "Volume Status is #{status}", true)

retry_method(10.seconds, "Volume Status: #{status}") unless status == "available"
