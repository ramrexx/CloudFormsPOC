#
# Description: <Method description here>
#

require 'rest_client'

$password = nil
$password ||= $evm.object.decrypt('password')

$username = 'admin'

$evm.root.attributes.sort.each { |k, v| $evm.log(:info,"Root:<$evm.root> Attributes - #{k}: #{v}")}

hostname = $evm.root['dialog_hostname_ems_ref']

RestClient.delete "https://#{$username}:#{$password}@sat6.local.domb.com/api/v2/hosts/#{hostname}"
