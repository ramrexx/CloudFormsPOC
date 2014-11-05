###################################
#
# CFME Automate Method: HostDeactivation
#
# Author: Kevin Morey
#
# Notes: This method evacuates a RHEV host by putting it into maintenance mode
#
###################################
begin
  # Method for logging
  def log(level, msg, update_message=false)
    @method = 'HostDeactivation'
    $evm.log(level, "#{@method} - #{msg}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # basic retry logic
  def retry_method(retry_time=1.minute)
    log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  def call_rhev(host, action, ref=nil, body_type=:xml, body=nil)
    require 'rest_client'
    require 'xmlsimple'
    require 'json'

    servername = host.ext_management_system.ipaddress
    username = host.ext_management_system.authentication_userid
    password = host.ext_management_system.authentication_password

    # if ref is a url then use that one instead
    unless ref.nil?
      url = ref if ref.include?('http')
    end
    url ||= "https://#{servername}#{ref}"

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
    log(:info, "Calling -> RHEVM: #{url} action: #{action} payload: #{params[:payload]}")

    response = RestClient::Request.new(params).execute
    unless response.code == 200 || response.code == 201 || response.code == 202
      raise "Failure <- RHEVM Response: #{response.code}"
    end
    # use XmlSimple to convert xml to ruby hash
    return XmlSimple.xml_in(response)
  end

  log(:info, "CFME Automate Method Started", true)

  # dump all root attributes to the log
  dump_root()

  case $evm.root['vmdb_object_type']

  when 'host'
    # get host from root
    host = $evm.root['host']
    log(:info, "List of VMs on host: #{host.name} ems_ref:<#{host.ems_ref}")
    host.vms.each {|vm| log(:info, "vm: #{vm.name}")}
    log(:info, "host: #{host.name} entering maintenance mode")
    deactivate_host_response = call_rhev(host, :post, "#{host.ems_ref}/deactivate", :xml, '<action></action>')
    log(:info, "deactivate_host_response: #{deactivate_host_response.inspect}")
  end

  # Exit method
  log(:info, "CFME Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
