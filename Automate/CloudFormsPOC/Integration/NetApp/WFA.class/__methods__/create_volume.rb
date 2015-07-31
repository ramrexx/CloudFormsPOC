# create_volume.rb
#
# Author: Carsten Clasohm <clasohm@redhat.com>
# License: GPL v3
#
# Description: Call NetApp's WFA to create a storage volume.
#   Can either be invoked in a service request, or during
#   VM provisioning.
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
  def call_netapp(action, ref=nil, body_type=:xml, body=nil)
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

  case $evm.root['vmdb_object_type']

  when 'miq_provision'
    # We are creating the storage volume as part of a VM provisioning request.
    
    @task = $evm.root['miq_provision']
    ws_values = @task.options[:ws_values]
    
    primary_cluster_name = ws_values[:primary_cluster_name]
    volume_name = ws_values[:volume_name]
    volume_size = ws_values[:volume_size]
    export_policy_name = ws_values[:export_policy_name]
    mirror_cluster_name = ws_values[:mirror_cluster_name]
    
    if volume_name.blank?
      $evm.log(:info, "Blank volume_name, skipping storage volume creation")
      exit MIQ_OK 
    end
      
    error("User did not specify primary_cluster_name") if primary_cluster_name.blank?
    error("User did not specify volume_size") if volume_size.blank?
    error("User did not specify export_policy_name") if export_policy_name.blank?
  
  when 'service_template_provision_task'
    # This is a separate service request to create a storage volume.

    @task = $evm.root['service_template_provision_task']
    dialog_options = @task.dialog_options

    $evm.log(:info, "dialog_options = #{dialog_options.inspect}")

    primary_cluster_name = dialog_options['dialog_primary_cluster_name']
    volume_name = dialog_options['dialog_volume_name']
    volume_size = dialog_options['dialog_volume_size']
    export_policy_name = dialog_options['dialog_export_policy_name']
    mirror_cluster_name = dialog_options['dialog_mirror_cluster_name']
  end

  # In the environment this was developed in, each storage cluster had one vserver, with the
  # name derived from the cluster name by replacing "sn" with "c".
  primary_vserver_name = primary_cluster_name.sub('sn', 'c')

  mirror_vserver_name = nil
  mirror_vserver_name = mirror_cluster_name.sub('sn', 'c') if mirror_cluster_name

  workflow_guid = $evm.object['workflow_guid']

  body_xml = "<workflowInput><userInputValues>"

  body_xml += "<userInputEntry key='ClusterName' value='#{primary_cluster_name}'/>"
  body_xml += "<userInputEntry key='VserverName' value='#{primary_vserver_name}'/>"
  body_xml += "<userInputEntry key='VolumeName' value='#{volume_name}'/>"
  body_xml += "<userInputEntry key='VolumeSizeGB' value='#{volume_size}'/>"
  body_xml += "<userInputEntry key='ExportPolicyName' value='#{export_policy_name}'/>"
  unless mirror_cluster_name.blank?
    body_xml += "<userInputEntry key='SnapMirrorDestinationClusterName' value='#{mirror_cluster_name}'/>"
    body_xml += "<userInputEntry key='SnapMirrorDestinationVserverName' value='#{mirror_vserver_name}'/>"
    body_xml += "<userInputEntry key='SnapMirrorPolicy' value='DPDefault'/>"
  end

  body_xml += "</userInputValues></workflowInput>"

  workflow_execute = call_netapp(:post, ref="/#{workflow_guid}/jobs", :xml, body=body_xml)

  job_id = workflow_execute.xpath('/job/@jobId')[0].content
  $evm.log(:info, "Got job ID #{job_id} from WFA")

  $evm.set_state_var('netapp_job_id', job_id)
  $evm.set_state_var('netapp_workflow_guid', workflow_guid)

rescue => err
  error("[#{err}]\n#{err.backtrace.join("\n")}")
end
