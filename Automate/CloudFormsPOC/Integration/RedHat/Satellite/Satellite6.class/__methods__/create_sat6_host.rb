#
# Description: Registers a baremetal server with sat6
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

#post_json(url+"hosts", JSON.generate({"name"=>hostname,"hostgroup_id"=>hostgroup_id,"organization_id"=>"3","compute_resource_id"=>compute_resource_id,"location_id"=>"4","managed"=>false,"build"=>false}))["id"]

post_json(url+"hosts", JSON.generate({"host" =>{"name"                  =>hostname,
                                       "environment_id"       =>environment_id,
                                       "domain_id"            =>"1",
                                       "hostgroup_id"         =>hostgroup_id,
                                       "location_id"          =>"4",
                                       "organization_id"      =>"3",
                                       "compute_resource_id"  =>"",
                                       "managed"              =>true,
                                       "mac"                  =>macaddr,
                                       "subnet_id"            =>"1",
                                       "ip"                   =>ipaddr,
                                       "architecture_id"      =>"1",
                                       "operatingsystem_id"   =>"2",
                                       "medium_id"            => "8",
                                       "provision_method"     =>"build",
                                       "build"=>"1",
                                       "ptable_id"=>"7",
                                       "root_pass"=>$password,
  }}))

if hostgroup_id == "4"
  post_json(url+"smart_class_parameters/322-db_host/override_values/", JSON.generate({"match" =>"fqdn=#{hostname}.local.domb.com",
                                       "value"       =>"db.local.domb.com",
                                       }))
end
