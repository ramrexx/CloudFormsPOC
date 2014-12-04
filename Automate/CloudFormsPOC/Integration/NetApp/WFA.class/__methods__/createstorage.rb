#
# CreateStorage.rb
#
# Description: This method leverages the Ruby REST API to call NetApp's WFA to create a storage
#
require 'rest_client'
require 'xmlsimple'
require 'json'
require 'base64'

def log(level, msg, update_message=false)
  $evm.log(level, "#{msg}")
  $evm.root['miq_provision'].message = "#{msg}" if $evm.root['miq_provision'] && update_message
end

def call_netapp(action, ref=nil, body_type=:xml, body=nil)
  servername = nil || $evm.object['servername']
  username = nil || $evm.object['username']
  password = nil || $evm.object.decrypt('password') || mil
  url = "https://#{servername}/rest/workflows"+"#{ref}"

  params = {
    :method=>action,
    :url=>url,
    #:user=>username,
    :password=>password,
    :headers=>{ :content_type=>body_type, :accept=>:xml, :authorization=>"Basic #{password}" }
  }
  if body_type == :json
    params[:payload] = JSON.generate(body) if body
  else
    params[:payload] = body if body
  end
  log(:info, "Calling -> NetApp:<#{url}> action:<#{action}> payload:<#{params[:payload]}>")

  response = RestClient::Request.new(params).execute
  log(:info, "NetApp response:<#{response.inspect}>")
  unless response.code == 200 || response.code == 201
    raise "Failure <- NetApp Response:<#{response.code}>"
  else
    log(:info, "Success <- NetApp Response:<#{response.code}>")
  end
  # use XmlSimple to convert xml to ruby hash
  response_hash = XmlSimple.xml_in(response)
  log(:info, "Inspecting response_hash: #{response_hash.inspect}")
  return response_hash
end

$evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

workflow_guid = nil || $evm.object['workflow_guid']

workflow = call_netapp(:get, ref="/#{workflow_guid}", :xml, body=nil)
log(:info, "workflow:<#{workflow.inspect}>")

body_xml = "<workflowInput><userInputValues>"
body_xml += "<userInputEntry key='Filer' value='pdclflr001'/>"
body_xml += "<userInputEntry key='Volume' value='lab_cloudforms'/>"
body_xml += "<userInputEntry key='Qtree' value='lab_cloudforms01'/>"
body_xml += "<userInputEntry key='Size' value='10'/>"
body_xml += "<userInputEntry key='Server' value='xllrhcfpoc001'/>"
body_xml += "</userInputValues></workflowInput>"

workflow_execute = call_netapp(:post, ref="/#{workflow_guid}/jobs", :xml, body=body_xml)
log(:info, "workflow_execute:<#{workflow_execute.inspect}>")
