##################################################
#
# CFME Automate Method: getConsoleURL
#
# by Marco Berube
#
# Note: Find instance console URL and publish it as a custom attribute
#
##################################################
begin
def log(level, msg)
@method = 'allocateFloatingIP'
$evm.log(level, "#{@method}: #{msg}")
end
def dump_root()
log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
$evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
log(:info, "Root:<$evm.root> End $evm.root.attributes")
log(:info, "")
end
#dump_root
require 'fog'
vm = nil
case $evm.root['vmdb_object_type']
when 'vm'
vm = $evm.root['vm']
end
raise "VM is nil" if vm.nil?
log(:info, "Nova instance UUID is #{vm.ems_ref}")
instance_uuid = vm.ems_ref
# GET OPENSTACK PROVIDER DETAILS
openstack = vm.ext_management_system
log(:info, "OpenStack #{openstack.inspect}")
log(:info, ":openstack_username: #{openstack.authentication_userid.inspect}")
log(:info, ":openstack_auth_url: http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens")
# CONNECT TO OPENSTACK PROVIDER
conn = Fog::Compute.new({
:provider => 'OpenStack',
:openstack_api_key => openstack.authentication_password,
:openstack_username => openstack.authentication_userid,
:openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
:openstack_tenant => "admin"
})
log(:info, "Got connection #{conn.class} #{conn.inspect}")
# GET CONSOLE URL
console_url = conn.get_vnc_console("#{instance_uuid}","novnc").body["console"]["url"]
log(:info, "console url : #{console_url}")
vm.custom_set("Console URL", "#{console_url}")
vm.refresh
rescue => err
log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
exit MIQ_ABORT
end
