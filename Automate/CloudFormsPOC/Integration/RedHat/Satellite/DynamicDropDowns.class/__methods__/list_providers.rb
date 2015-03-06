# List_Providers.rb
#
# Description: List the Providers 
#

require 'rest-client'
require 'json'

# Get Satellite password from model else set it here
$password = nil
$password ||= $evm.object.decrypt('password')

url = 'https://sat6.local.domb.com/api/v2/'
katello_url = 'https://sat6.local.domb.com/katello/api/v2/'
$username = 'admin'

def get_json(compute_resources)
    response = RestClient::Request.new(
        :method => :get,
        :url => compute_resources,
        :user => $username,
        :password => $password,
        :headers => { :accept => :json,
        :content_type => :json }
    ).execute
    results = JSON.parse(response.to_str)
end

computeresources = get_json(url+"compute_resources")
computeresourceslist = {}
computeresources['results'].each do |provider|
  puts provider['name']
  computeresourceslist[provider['id']] = provider['name']
end


$evm.object['values'] = [['""','Bare Metal']] + computeresourceslist.to_a.sort
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")
