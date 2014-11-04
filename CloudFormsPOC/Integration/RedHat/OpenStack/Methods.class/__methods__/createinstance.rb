# createInstance.rb
#
# Description: Create intance in OpenStack
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

conn = Fog::Compute.new({
                          :provider => 'OpenStack',
                          :openstack_api_key => openstack.authentication_password,
                          :openstack_username => openstack.authentication_userid,
                          :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
                          :openstack_tenant => tenant.name
})

$evm.log(:info, "Successfully connected to Nova Service at #{openstack.name}")

volume = $evm.get_state_var(:volume)
raise "missing volume" if volume.blank?
$evm.log(:info, "Volume information: #{volume.inspect}")

ct_id = $evm.root['dialog_ct_id']
ct = $evm.vmdb(:customization_template).find_by_id(ct_id)
$evm.log(:info, "cloud-init: #{ct.inspect}")

user_data = ct.script rescue nil

flavor_id = $evm.root['dialog_flavor']
flavor = $evm.vmdb(:flavor_openstack).find_by_id(flavor_id)
$evm.log(:info, "flavor: #{flavor.name} ems_ref: #{flavor.ems_ref}")

ssh_key = $evm.root['dialog_ssh_key_id'] 
network_id = $evm.root['dialog_network_id_id'] 

launch_instance_hash = {}
launch_instance_hash[:name] = instance_name unless instance_name.nil?
launch_instance_hash[:flavor_ref] = flavor.ems_ref unless flavor.nil?
launch_instance_hash[:user_data] = user_data unless user_data.nil?
launch_instance_hash[:key_name] = ssh_key.name unless ssh_key.nil?
launch_instance_hash[:network_id] = network_id unless network_id.nil?
launch_instance_hash[:block_device_mapping] = [
  {
    :volume_size => '',
    :volume_id => volume['id'],
    :delete_on_termination => 1,
    :device_name => 'vda'
}]

server = conn.servers.create(launch_instance_hash)

$evm.log(:info, "Create server response: #{server.inspect}")
$evm.set_state_var(:server, server.id)
$evm.log(:info, "Server ID: #{$evm.get_state_var(:server)}")
