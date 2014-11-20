# createInstance.rb
#
# Description: Create intance in OpenStack
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
log(:info, "EMS_Openstack: #{openstack.inspect}\n#{openstack.methods.sort.inspect}")

tenant = get_tenant
log(:info, "Using tenant: #{tenant.name}")

conn = Fog::Compute.new({
                          :provider => 'OpenStack',
                          :openstack_api_key => openstack.authentication_password,
                          :openstack_username => openstack.authentication_userid,
                          :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
                          :openstack_tenant => tenant.name
})

log(:info, "Successfully connected to Nova Service at #{openstack.name}", true)

volume_id = service_template_provision_task.get_option(:volume_id)

ct_id = $evm.root['dialog_ct_id']
unless ct_id.nil?
  ct = $evm.vmdb(:customization_template).find_by_id(ct_id)
  log(:info, "cloud-init: #{ct.inspect}")
end

user_data = ct.script rescue nil

flavor_id = $evm.root['dialog_flavor']
unless flavor_id.nil?
  flavor = $evm.vmdb(:flavor_openstack).find_by_id(flavor_id)
  log(:info, "flavor: #{flavor.name} ems_ref: #{flavor.ems_ref}")
end

ssh_key = $evm.root['dialog_ssh_key_id']
network_id = $evm.root['dialog_network_id']

launch_instance_hash = {}
launch_instance_hash[:name] = instance_name unless instance_name.nil?
launch_instance_hash[:flavor_ref] = flavor.ems_ref unless flavor.nil?
launch_instance_hash[:user_data] = user_data unless user_data.nil?
launch_instance_hash[:key_name] = ssh_key.name unless ssh_key.nil?
launch_instance_hash[:network_id] = network_id unless network_id.nil?
launch_instance_hash[:block_device_mapping] = [
  {
    :volume_size => '',
    :volume_id => volume_id,
    :delete_on_termination => 1,
    :device_name => 'vda'
}]

server = conn.servers.create(launch_instance_hash)

log(:info, "Create server response: #{server.inspect}")
service.custom_set("SERVER_ID", "#{server.id}")
service_template_provision_task.set_option(:server_id, server.id)
log(:info, "Server ID: #{service_template_provision_task.get_option(:server_id)}", true)
