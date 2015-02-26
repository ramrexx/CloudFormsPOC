# List_Hostgroups.rb
#
# Description: List the Hostgroups
#

require 'rest-client'
require 'json'


# Get Satellite password from model else set it here
$password = nil
$password ||= $evm.object.decrypt('password')

url = 'https://sat6.local.domb.com/api/v2/'
katello_url = 'https://sat6.local.domb.com/katello/api/v2/'
$username = 'admin'


def get_json(hostgroups)
    response = RestClient::Request.new(
        :method => :get,
        :url => hostgroups,
        :user => $username,
        :password => $password,
        :headers => { :accept => :json,
        :content_type => :json }
    ).execute
    results = JSON.parse(response.to_str)
end


hgroup = get_json(url+"hostgroups")
hgroup_list = {}
hgroup['results'].each do |hgroup|
    hgroup_list[hgroup['id']] = hgroup['name']
end


$evm.object['values'] = hgroup_list
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")
