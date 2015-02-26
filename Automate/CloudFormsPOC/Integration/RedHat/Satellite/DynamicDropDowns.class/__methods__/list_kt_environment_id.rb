# List_kt_environment_id.rb
#
# Description: List kt_environment_id
#

require 'rest-client'
require 'json'


# Get Satellite password from model else set it here
$password = nil
$password ||= $evm.object.decrypt('password')

url = 'https://sat6.local.domb.com/api/v2/'
katello_url = 'https://sat6.local.domb.com/katello/api/v2/'
$username = 'admin'


def get_json(environments)
    response = RestClient::Request.new(
        :method => :get,
        :url => environments,
        :user => $username,
        :password => $password,
        :headers => { :accept => :json,
        :content_type => :json }
    ).execute
    results = JSON.parse(response.to_str)
end


lifecycleenvs = get_json(katello_url+"organizations/3/environments")
lifecycleenvs_list = {}
lifecycleenvs['results'].each do |lifecyclenev|
  lifecycleenvs_list[lifecyclenev['name']] = lifecyclenev['name']
end


$evm.object['values'] = lifecycleenvs_list
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")

