# List_environment_id.rb
#
# Description: List the List_environment_ids
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


contentviews = get_json(url+"environments")
contentview_list = {}
contentviews['results'].each do |contentview|
  contentview_list[contentview['id']] = contentview['name']
end


$evm.object['values'] = contentview_list
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")
