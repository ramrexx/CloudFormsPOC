# check_job_status.rb
#
# Author: Carsten Clasohm <clasohm@redhat.com>
# License: GPL v3
#
# Description: Check the status of a NetApp WFA job.
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
  def retry_method(msg, retry_time=1.minute)
    $evm.log(:info, "Retrying in #{retry_time} seconds: [#{msg}]")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  def delete_service
    if @task.destination
      # Remove the service from the VMDB.
      service = @task.destination
      $evm.log(:info, "Deleting service #{service.id}")
      service.remove_from_vmdb
    end
  end

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
      :headers=>{ :content_type=>body_type, :accept=>:xml, :authorization=>"Basic #{password}" }
    }
    
    if body_type == :json
      params[:payload] = JSON.generate(body) if body
    else
      params[:payload] = body if body
    end
    $evm.log(:info, "Calling -> NetApp:<#{url}> action:<#{action}> payload:<#{params[:payload]}>")

    begin
      response = RestClient::Request.new(params).execute
    rescue => e
      msg = "#{e}, #{e.response}"
      
      delete_service
      
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
    @task = $evm.root['miq_provision']
  when 'service_template_provision_task'
    @task = $evm.root['service_template_provision_task']
  end

  job_id = $evm.get_state_var('netapp_job_id')

  if job_id.blank?
    $evm.log(:info, "No job ID found, skipping job status check.")
  else
    workflow_guid = $evm.get_state_var('netapp_workflow_guid')
    job = call_netapp(:get, ref="/#{workflow_guid}/jobs/#{job_id}", :xml, body=nil)

    job_status = job.xpath('/job/jobStatus/jobStatus')[0].content

    if job_status == 'COMPLETED'
      $evm.log(:info, "Job completed")
    elsif ['PLANNING', 'EXECUTING', 'SCHEDULED', 'PAUSED'].include?(job_status)
      retry_method("NetApp WFA job executing, status #{job_status}", 1.minute)
    else
      error_message = job.xpath('/job/jobStatus/errorMessage')[0].content
      msg = "NetApp WFA job status: #{job_status}, error message: [#{error_message}]"
    
      delete_service
    
      error(msg)
    end
  end

rescue => err
  error("[#{err}]\n#{err.backtrace.join("\n")}")
end
