#
# Description: CreateMultihost Via Service Catalog rest api
#

require 'rest-client'
require 'json'

# Get Satellite password from model else set it here
$password = nil
$password ||= $evm.object.decrypt('passwordems')


url = 'https://cloudforms.local.domb.com/api/'
$username = 'admin'


def post_json(service_templates, json_data)
    response = RestClient::Request.new(
        :method => :post,
        :url => service_templates,
        :user => $username,
        :password => $password,
        :headers => { :accept => :json,
        :content_type => :json},
        :payload => json_data
    ).execute
    results = JSON.parse(response.to_str)
end


$evm.root.attributes.sort.each { |k, v| $evm.log(:info,"Root:<$evm.root> Attributes - #{k}: #{v}")}

#347000000000013 CreateHAPROXY
#347000000000014 CreateMysql
#347000000000015 CreateWordpress


#MYSQL config
mysql_name = $evm.root['dialog_mysql_name_ems_ref']
mysql_ipaddr = $evm.root['dialog_mysql_ipaddr_ems_ref']
mysql_memory = $evm.root['dialog_mysql_memory_ems_ref']
mysql_disksize = $evm.root['dialog_mysql_disksize_ems_ref']

#WORDPRESS


wp1_memory = $evm.root['dialog_wp1_memory_ems_ref']
wp1_disksize = $evm.root['dialog_wp1_disksize_ems_ref']



wp2_memory = $evm.root['dialog_wp2_memory_ems_ref']
wp2_disksize = $evm.root['dialog_wp2_disksize_ems_ref']

#HAPROXY

haproxy_name = $evm.root['dialog_haproxy_name_ems_ref']
haproxy_ipaddr = $evm.root['dialog_haproxy_ipaddr_ems_ref']
haproxy_memory = $evm.root['dialog_haproxy_memory_ems_ref']
haproxy_disksize = $evm.root['dialog_haproxy_disksize_ems_ref']


haproxy_hostname_wordpress0 = $evm.root['dialog_haproxy_hostname_wordpress0_ems_ref']
haproxy_hostname_wordpress1 = $evm.root['dialog_haproxy_hostname_wordpress1_ems_ref']
haproxy_ipaddress_wordpress0 = $evm.root['dialog_haproxy_ipaddress_wordpress0_ems_ref']
haproxy_ipaddress_wordpress1 = $evm.root['dialog_haproxy_ipaddress_wordpress1_ems_ref']



post_json(url+"service_catalogs/347000000000003/service_templates", JSON.generate({
                                       "action"             =>"order",
                                       "service_name"       =>"wp1",
                                       "href"               =>"http://localhost:3000/api/services_templates/347000000000015",
                                       "ipaddr_ems_ref"     =>haproxy_ipaddress_wordpress0,
                                       "name_ems_ref"       =>haproxy_hostname_wordpress0,
                                       "memory_ems_ref"     =>wp1_memory,
                                       "disksize_ems_ref"   =>wp1_disksize,
                                       "db_host_ems_ref"    =>mysql_ipaddr,
                                       }))




post_json(url+"service_catalogs/347000000000003/service_templates", JSON.generate({
                                       "action"             =>"order",
                                       "service_name"       =>"wp2",
                                       "href"               =>"http://localhost:3000/api/services_templates/347000000000015",
                                       "ipaddr_ems_ref"     =>haproxy_ipaddress_wordpress1,
                                       "name_ems_ref"       =>haproxy_hostname_wordpress1,
                                       "memory_ems_ref"     =>wp2_memory,
                                       "disksize_ems_ref"   =>wp2_disksize,
                                       "db_host_ems_ref"    =>mysql_ipaddr,
                                       }))



post_json(url+"service_catalogs/347000000000003/service_templates", JSON.generate({
                                       "action"             =>"order",
                                       "service_name"       =>"haproxy",
                                       "href"               =>"http://localhost:3000/api/services_templates/347000000000013",
                                       "ipaddr_ems_ref"     =>haproxy_ipaddr,
                                       "name_ems_ref"       =>haproxy_name,
                                       "memory_ems_ref"     =>haproxy_memory,
                                       "disksize_ems_ref"   =>haproxy_disksize,
                                       "hostname_wordpress0_ems_ref" =>haproxy_hostname_wordpress0,
                                       "hostname_wordpress1_ems_ref" =>haproxy_hostname_wordpress1,
                                       "ipaddress_wordpress0_ems_ref" =>haproxy_ipaddress_wordpress0,
                                       "ipaddress_wordpress1_ems_ref" =>haproxy_ipaddress_wordpress1,
                                       }))


post_json(url+"service_catalogs/347000000000003/service_templates", JSON.generate({
                                       "action"             =>"order",
                                       "service_name"       =>"mysql",
                                       "href"               =>"http://localhost:3000/api/services_templates/347000000000014",
                                       "name_ems_ref"       =>mysql_name,
                                       "ipaddr_ems_ref"     =>mysql_ipaddr,
                                       "memory_ems_ref"     =>mysql_memory,
                                       "disksize_ems_ref"   =>mysql_disksize,
                                       }))





