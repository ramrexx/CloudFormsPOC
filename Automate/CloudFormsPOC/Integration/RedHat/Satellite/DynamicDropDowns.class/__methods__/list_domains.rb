# List_Domains.rb
#
# Description: List the Domains In Sat6
#

require 'rest-client'
require 'json'


# Get Satellite password from model else set it here
$password = nil
$password ||= $evm.object.decrypt('password')

url = 'https://sat6.local.domb.com/api/v2/'
katello_url = 'https://sat6.local.domb.com/katello/api/v2/'
$username = 'admin'

def get_json(domains)
    response = RestClient::Request.new(
        :method => :get,
        :url => domains,
        :user => $username,
        :password => $password,
        :headers => { :accept => :json,
        :content_type => :json }
    ).execute
    results = JSON.parse(response.to_str)
end

domains = get_json(url+"domains")
domainslist = {}
domains['results'].each do |domain|
  puts domain['name']
  domainslist[domain['id']] = domain['name']
end

$evm.object['values'] = domainslist.to_a
$evm.log(:info, "Dialog Values: #{$evm.object['values'].inspect}")
