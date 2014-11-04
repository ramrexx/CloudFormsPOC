# check_createVolume.rb
#
# Description: check creation of a volume in OpenStack
#
require 'fog'

def get_tenant
  tenant_ems_id = $evm.root['dialog_cloud_tenant']
  $evm.log(:info, "Found EMS ID of tenant from dialog: #{tenant_ems_id}")
  return tenant_ems_id if tenant_ems_id.nil?

  tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
  $evm.log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
  return tenant
end

# basic retry logic
def retry_method(retry_time=1.minute)
  $evm.log(:info, "Sleeping for #{retry_time} seconds")
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

$evm.root.attributes.sort.each { |k, v| $evm.log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

mid = $evm.root['dialog_mid']
raise "Management System ID is nil" if mid.blank?
openstack = nil

unless mid.blank?
  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
else
  openstack = $evm.vmdb(:ems_openstack).all.first
end

raise "OpenStack Management system with id '#{mid}' not found" if openstack.nil?
$evm.log(:info, "EMS_Openstack: #{openstack.inspect}\n#{openstack.methods.sort.inspect}")

tenant = get_tenant
$evm.log(:info, "Using tenant: #{tenant.name}")

conn = Fog::Volume.new({
                         :provider => 'OpenStack',
                         :openstack_api_key => openstack.authentication_password,
                         :openstack_username => openstack.authentication_userid,
                         :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
                         :openstack_tenant => tenant.name
})

$evm.log(:info, "Successfully connected to Storage Service at #{openstack.name}")

volume = $evm.get_state_var(:volume)
raise "missing volume" if volume.blank?
$evm.log(:info, "Volume information: #{volume.inspect}")

volume_id = volume['id']
details = conn.get_volume_details(volume_id).body['volume']

status = details['status']
$evm.log(:info, "Current Status is #{status}")

retry_method(10.seconds) unless status == "available"
