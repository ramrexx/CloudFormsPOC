# List_Hosts.rb
#
# Description: List the Hosts In the org

require 'rest-client'
require 'json'


# Get Satellite password from model else set it here
$password = nil
$password ||= $evm.object.decrypt('password')

url = 'https://sat6.local.domb.com/api/v2/'
katello_url = 'https://sat6.local.domb.com/katello/api/v2/'
$username = 'admin'

def get_json(hosts)
    response = RestClient::Request.new(
        :method => :get,
        :url => hosts,
        :user => $username,
        :password => $password,
        :headers => { :accept => :json,
        :content_type => :json }
    ).execute
    results = JSON.parse(response.to_str)
end

hosts = get_json(url+"hosts")
hostslist = {}
hosts['results'].each do |host|
  hostslist[host['id']] = host['name']
end



$evm.object['values'] = hostslist.except(1).to_a
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")
