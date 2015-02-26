#
# Description: <Method description here>
#

require 'rest-client'
require 'json'

# Get Satellite password from model else set it here
$password = nil
$password ||= $evm.object.decrypt('password')


url = 'https://sat6.local.domb.com/api/v2/'
$username = 'admin'


def post_json(hosts, json_data)
    response = RestClient::Request.new(
        :method => :post,
        :url => hosts,
        :user => $username,
        :password => $password,
        :headers => { :accept => :json,
        :content_type => :json},
        :timeout => 90000000,
        :payload => json_data
    ).execute
    results = JSON.parse(response.to_str)
end

$evm.root.attributes.sort.each { |k, v| $evm.log(:info,"Root:<$evm.root> Attributes - #{k}: #{v}")}

hostname = $evm.root['dialog_name_ems_ref']
hostgroup_id = $evm.root['dialog_hostgroup_ems_ref']
compute_resource_id = $evm.root['dialog_provider_ems_ref']
ipaddr = $evm.root['dialog_ipaddr_ems_ref']
macaddr = $evm.root['dialog_macaddr_ems_ref']
environment_id = $evm.root['dialog_contentview_ems_ref']
lifecycle =  $evm.root['dialog_lifecycleenv_ems_ref']
memory =  $evm.root['dialog_memory_ems_ref']
disksize =  $evm.root['dialog_disksize_ems_ref']

#Override params
db_host =  $evm.root['dialog_db_host_ems_ref']
hostname_wordpress0 =  $evm.root['dialog_hostname_wordpress0_ems_ref']
hostname_wordpress1 =  $evm.root['dialog_hostname_wordpress1_ems_ref']
ipaddress_wordpress0 = $evm.root['dialog_ipaddress_wordpress0_ems_ref']
ipaddress_wordpress1 = $evm.root['dialog_ipaddress_wordpress1_ems_ref']

post_json(url+"hosts", JSON.generate({"host" => {
  "name"=>hostname,
"organization_id"=>"3",
"location_id"=>"4",
"hostgroup_id"=>"5",
"compute_resource_id"=>"1",
"environment_id"=>"5",
"content_source_id"=>"1",
"managed"=>"true",
"type"=>"Host::Managed",
  "compute_attributes"=>{"cpus"=>"1", "corespersocket"=>"1", "memory_mb"=>memory, "cluster"=>"dombcluster", "path"=>"/Datacenters/domb/vm", "guest_id"=>"otherGuest64", "interfaces_attributes"=>{"new_interfaces"=>{"type"=>"VirtualE1000", "network"=>"network-169", "_delete"=>""}, "0"=>{"type"=>"VirtualE1000", "network"=>"network-169", "_delete"=>""}}, "volumes_attributes"=>{"new_volumes"=>{"datastore"=>"esxinfs", "name"=>"Hard disk", "size_gb"=>disksize, "thin"=>"true", "_delete"=>""}, "0"=>{"datastore"=>"esxinfs", "name"=>"Hard disk", "size_gb"=>"10", "thin"=>"true", "_delete"=>""}}, "scsi_controller_type"=>"VirtualLsiLogicController", "start"=>"1", "image_id"=>"templates/rhel6bare"},
"domain_id"=>"1",
"realm_id"=>"",
"mac"=>"",
"subnet_id"=>"1",
"ip"=>ipaddr,
"interfaces_attributes"=>{"new_interfaces"=>{"_destroy"=>"false", "type"=>"Nic::Managed", "mac"=>"", "name"=>"", "domain_id"=>"", "ip"=>"", "provider"=>"IPMI"}},
"architecture_id"=>"1",
"operatingsystem_id"=>"2",
"provision_method"=>"image",
"build"=>"1",
"disk"=>"",
"enabled"=>"1",
"model_id"=>"",
"comment"=>"",
"overwrite"=>"false",
  "lookup_values_attributes"=>{"1421141338230"=>{"lookup_key_id"=>"243", "value"=>db_host, "_destroy"=>"false"}},
  }}))





