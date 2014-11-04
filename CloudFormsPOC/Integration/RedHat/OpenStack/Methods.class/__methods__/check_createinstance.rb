# check_createInstance.rb
#
# Description: Checks creation of an intance in OpenStack
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

instance_name = $evm.root['dialog_instance_name']

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

conn = Fog::Compute.new(
  {
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant.name
})

server_id = $evm.get_state_var(:server)

$evm.log(:info, "Server ID: #{server_id}")

details = conn.get_server_details(server_id)
$evm.log(:info, "Details: #{details.inspect}")

status = details[:body]["server"]["status"]
$evm.log(:info, "Current Status: #{status}")

retry_method(10.seconds) unless status == "ACTIVE"

vm = $evm.vmdb('vm').all.detect {|v| v.ems_ref == server_id }

if vm.nil?
  openstack.refresh
  retry_method()
end
$evm.log(:info, "Found VM: #{vm.name} guid: #{vm.guid}")
$evm.set_state_var(:vm_guid, vm.guid)
