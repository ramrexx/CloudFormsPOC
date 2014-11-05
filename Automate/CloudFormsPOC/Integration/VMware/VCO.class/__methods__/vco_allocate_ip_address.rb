###################################
#
# CFME Automate Method: VCO_Allocate_IP_Address
#
# Inputs: This method call VCO run a specific workflow
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'VCO_Allocate_IP_Address'
    $evm.log(level, "#{@method} - #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def call_vco(action, ref=nil, body_type=:xml, body=nil)
    require 'rest_client'
    require 'xmlsimple'
    require 'json'

    servername = nil || $evm.object['servername']
    username = nil   || $evm.object['username']
    password = nil   || $evm.object.decrypt('password')

    # if ref is a url then use that one instead
    unless ref.nil?
      if ref.include?('http')
        url = ref
      else
        url = "https://#{servername}/vco/api/workflows/#{ref}"
      end
    else
      url = "https://#{servername}/vco/api/workflows"
    end

    params = {
      :method=>action,
      :url=>url,
      :user=>username,
      :password=>password,
      :headers=>{ :content_type=>body_type, :accept=>:xml }
    }
    if body_type == :json
      params[:payload] = JSON.generate(body) if body
    else
      params[:payload] = body if body
    end
    log(:info, "Calling -> VCO:<#{url}> action:<#{action}> payload:#{params[:payload]}")

    response = RestClient::Request.new(params).execute
    log(:info, "Inspecting -> VCO response:<#{response.inspect}>")
    log(:info, "Inspecting -> VCO headers:<#{response.headers.inspect}>")
    unless response.code == 200 || response.code == 201 || response.code == 202
      raise "Failure <- VCO Response:<#{response.code}>"
    else
      log(:info, "Success <- VCO Response:<#{response.code}>")
    end
    # use XmlSimple to convert xml to ruby hash
    #response_hash = XmlSimple.xml_in(response)
    #log(:info, "Inspecting response_hash: #{response_hash.inspect}")
    return response
  end


  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  case $evm.root['vmdb_object_type']

  when 'miq_provision'
    prov = $evm.root['miq_provision']
    log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")
    if prov.options.has_key?(:ws_values)
      ws_values = prov.options[:ws_values]
      fg_ip_alloc_comment = ws_values[:fg_ip_alloc_comment]
      fg_vlan             = ws_values[:fg_vlan]
      fg_static_ip        = ws_values[:fg_static_ip]
    else
      fg_ip_alloc_comment = prov.get_option(:fg_ip_alloc_comment)
      fg_vlan             = prov.get_option(:fg_vlan)
      fg_static_ip        = prov.get_option(:fg_vlan)
    end
    fg_environment      = prov.get_tags[:environment] || 'tr1'
    fg_hostname         = prov.get_option(:vm_target_hostname) || prov.get_option(:vm_target_name)
  else
    log(:info, "Simulating Request")
    fg_environment      = 'tr1'
    fg_hostname         = 'fgtd-cloudforms-testvm-app001' #dialog_options['dialog_fg_hostname']
    fg_ip_alloc_comment = '' #dialog_options['dialog_fg_ip_alloc_comment']
    fg_vlan             = '' #dialog_options['dialog_fg_vlan']
    fg_static_ip        = '' #dialog_options['dialog_fg_static_ip']
  end

  log(:info, "fg_environment:<#{fg_environment}> fg_hostname:<#{fg_hostname}> fg_ip_alloc_comment:<#{fg_ip_alloc_comment}> fg_vlan:<#{fg_vlan}> fg_static_ip:<#{fg_static_ip}>")

  post_body = "<vco:execution-context xmlns:vco='http://www.vmware.com/vco' xmlns='vco'>"
  post_body += "<vco:parameters>"
  post_body += "<vco:parameter name='environment' type='string' description='Target network environment for deployment'><vco:string>#{fg_environment}</vco:string></vco:parameter>"
  post_body += "<vco:parameter name='hostname' type='string' description='Requested hostname (FQDN)'><vco:string>#{fg_hostname}</vco:string></vco:parameter>"
  post_body += "<vco:parameter name='comment' type='string' description='(Optional) Comment to assign to host object'><vco:string>#{fg_ip_alloc_comment}</vco:string></vco:parameter>"
  post_body += "<vco:parameter name='vlan' type='number' description='(Optional) VLAN id for network selection'><vco:number>#{fg_vlan}</vco:number></vco:parameter>"
  post_body += "<vco:parameter name='staticIP' type='string' description='(Optional) IP address to assign to host'><vco:string>#{fg_static_ip}</vco:string></vco:parameter>"
  post_body += "</vco:parameters></vco:execution-context>"

  workflow_guid = nil || $evm.object['workflow_guid']
  response = call_vco(:post, "#{workflow_guid}/executions", :xml, post_body)

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
