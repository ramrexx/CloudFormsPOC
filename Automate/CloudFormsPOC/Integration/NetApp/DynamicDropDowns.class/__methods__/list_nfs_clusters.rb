# list_nfs_clusters.rb
#
# Author: Carsten Clasohm <clasohm@redhat.com>
# License: GPL v3
#
# Description:
#   List clusters available for the NFS volume workflow.
#

require 'nokogiri'
require 'rest_client'

begin
  def call_netapp(action, ref=nil, body=nil)
    servername = nil || $evm.object['servername']
    username = nil || $evm.object['username']
    password = nil || $evm.object.decrypt('password') || mil
    url = "https://#{servername}/rest/workflows"+"#{ref}"

    params = {
      :method => action,
      :url => url,
      :verify_ssl => false,
      :user => username,
      :password => password,
      :headers => { :content_type=>:xml, :accept=>:xml, :authorization=>"Basic #{password}" },
      :payload => body
    }
    
    $evm.log(:info, "Calling -> NetApp:<#{url}> action:<#{action}> payload:<#{params[:payload]}>")

    response = RestClient::Request.new(params).execute
    $evm.log(:info, "NetApp response:<#{response.inspect}>")
    unless response.code == 200 || response.code == 201
      raise "Failure <- NetApp Response:<#{response.code}>"
    else
      $evm.log(:info, "Success <- NetApp Response:<#{response.code}>")
    end
  
    return Nokogiri::XML.parse(response)
  end

  workflow_guid = $evm.object['workflow_guid']
  workflow = call_netapp(:get, ref="/#{workflow_guid}")

  dialog_hash = {'' => ' < Choose >'}

  # Get the list of cluster names.
  workflow.xpath("/workflow/userInputList/userInput[name = 'ClusterName']/allowedValues/value").each do |cn| 
    cluster_name = cn.content
    dialog_hash[cluster_name] = cluster_name
  end

  $evm.object['values'] = dialog_hash

  $evm.log(:info, "dialog_hash = #{dialog_hash}")

  # Set Ruby rescue behavior
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
