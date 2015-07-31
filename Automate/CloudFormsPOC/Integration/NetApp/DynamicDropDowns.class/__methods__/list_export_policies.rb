# list_export_policies.rb
#
# Author: Carsten Clasohm <clasohm@redhat.com>
# License: GPL v3
#
# Description:
#   List export policies available for the NFS volume workflow.
#   This assumes that a filter has been created in NetApp that
#   lists the export policies for a given storage cluster.
#   It also assumes that the dialog has a field named
#   primary_cluster_name which the user has to select first.
#

require 'nokogiri'
require 'rest_client'

begin
  def call_netapp(action, ref=nil, body=nil)
    servername = $evm.object['servername']
    username = $evm.object['username']
    password = $evm.object.decrypt('password')
    url = "https://#{servername}/rest/filters"+"#{ref}"

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

  # The option name is different for the NetApp and the VM provisioning dialogs.
  cluster_name = $evm.root['dialog_primary_cluster_name']
  cluster_name = $evm.root['dialog_option_1_primary_cluster_name'] unless cluster_name

  dialog_hash = {'' => ' < Choose >'}
  if cluster_name.blank?
    dialog_hash[''] = '< Choose Primary Cluster and Refresh >'
    
    # Because of a bug in CloudForms 3.2, the drop-down list is changed into a text field 
    # if the list of options only has one element. Pressing the Refresh button will cause
    # a JavaScript error, freezing the form at the spinning wheel.
    dialog_hash['0'] = '< Choose Primary Cluster and Refresh >'
  else
    # In the environment this was developed in, each storage cluster had one vserver, with the
    # name derived from the cluster name by replacing "sn" with "c".
    vserver_name = cluster_name.sub('sn', 'c')

    filter_guid = $evm.object['filter_guid']
    ref = "/#{filter_guid}/test?cluster_name=#{cluster_name}&vserver_name=#{vserver_name}"

    export_policies = call_netapp(:get, ref)
    
    $evm.log(:info, "export_policies = #{export_policies}")

    # Get the list of export policy names.
    export_policies.xpath("/filterTestResults/rows/row/cell[@key = 'name']").each do |cell| 
      policy_name = cell['value']
      dialog_hash[policy_name] = policy_name
    end
  end

  $evm.object['values'] = dialog_hash

  $evm.log(:info, "dialog_hash = #{dialog_hash}")

  # Set Ruby rescue behavior
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
