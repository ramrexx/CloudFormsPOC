# delete_volume.rb
#
# Author: Carsten Clasohm <clasohm@redhat.com>
# License: GPL v3
#
# Description: Call NetApp's WFA to delete a storage volume.
#


require 'rest_client'
require 'nokogiri'

def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg
  exit MIQ_OK
end

begin
  def call_netapp(action, ref=nil, body=nil)
    servername = $evm.object['servername']
    username = $evm.object['username']
    password = $evm.object.decrypt('password')
    url = "https://#{servername}/rest/workflows"+"#{ref}"

    params = {
      :method => action,
      :url => url,
      :verify_ssl => false,
      :user => username,
      :password => password,
      :headers => { :content_type=>body_type, :accept=>:xml, :authorization=>"Basic #{password}" },
      :payload => body
    }

    $evm.log(:info, "Calling -> NetApp:<#{url}> action:<#{action}> payload:<#{params[:payload]}>")

    response = nil
    begin
      response = RestClient::Request.new(params).execute
    rescue => e
      msg = "#{e}, #{e.response}"
      
      # Remove the service from the VMDB.
      service = @task.destination
      $evm.log(:info, "Deleting service #{service.id}")
      service.remove_from_vmdb
      
      error("Error calling NetApp: #{msg}")
    end
  
    $evm.log(:info, "NetApp response:<#{response.inspect}>")
    unless response.code == 200 || response.code == 201
      raise "Failure <- NetApp Response:<#{response.code}>"
    else
      $evm.log(:info, "Success <- NetApp Response:<#{response.code}>")
    end

    results = Nokogiri::XML.parse(response)
    $evm.log(:info, "results = #{results}")
    return results
  end

  @task = $evm.root['service_template_provision_task']
  dialog_options = @task.dialog_options

  $evm.log(:info, "dialog_options = #{dialog_options.inspect}")

  primary_cluster_name = dialog_options['dialog_primary_cluster_name']

  # In the environment this was developed in, each storage cluster had one vserver, with the
  # name derived from the cluster name by replacing "sn" with "c".
  primary_vserver_name = primary_cluster_name.sub('sn', 'c')
  
  volume_name = dialog_options['dialog_volume_name']
  
  body_xml = "<workflowInput><userInputValues>"
  
  body_xml += "<userInputEntry key='ClusterIp' value='#{primary_cluster_name}'/>"
  body_xml += "<userInputEntry key='VserverName' value='#{primary_vserver_name}'/>"
  body_xml += "<userInputEntry key='VolumeName' value='#{volume_name}'/>"
  
  body_xml += "</userInputValues></workflowInput>"

  workflow_guid = $evm.object['workflow_guid']

  workflow_execute = call_netapp(:post, ref="/#{workflow_guid}/jobs", :xml, body=body_xml)

  job_id = workflow_execute.xpath('/job/@jobId')[0].content
  $evm.log(:info, "Got job ID #{job_id} from WFA")
  $evm.set_state_var('netapp_job_id', job_id)
  $evm.set_state_var('netapp_workflow_guid', workflow_guid)

  # Set Ruby rescue behavior
rescue => err
  error("[#{err}]\n#{err.backtrace.join("\n")}")
end
