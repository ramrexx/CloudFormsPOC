###################################
#
# CFME Automate Method: vCloud_VMPowerOperations
#
# Author: Kevin Morey
#
###################################
begin
  require 'rest_client'
  require 'xmlsimple'
  require 'json'

  # Method for logging
  def log(level, msg, update_message=false)
    @method = 'vCloud_VMPowerOperations'
    $evm.log(level, "#{@method} - #{msg}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def login_vcloud(servername, username, password, ref)
    url = "https://#{servername}"+"#{ref}"
    headers = {}
    headers[:content_type] = :xml
    headers[:accept] = 'application/*+xml;version=5.1'
    headers[:content_length] = 0

    params = {
      :method=>:post,
      :url=>url,
      :user=>username,
      :password=>password,
      :headers=>headers
    }
    log(:info, "Logging into vCloud: #{url}")
    authorization_response = RestClient::Request.new(params).execute
    log(:info, "Successfully logged into vCloud: #{authorization_response.code}")
    @cookie = authorization_response.headers[:x_vcloud_authorization]
    log(:info, "Detected API session cookie: #{@cookie}")
    unless authorization_response.code == 200 || authorization_response.code == 201 || authorization_response.code == 202
      raise "Failed to log into vCloud: #{authorization_response.code}"
    end
  end

  def call_vcloud(action, ref=nil, content_type=:xml, accept=:xml, body=nil)

    servername = nil || $evm.object['servername']
    username = nil || $evm.object['username']
    password = nil || $evm.object.decrypt('password')

    login_vcloud(servername, username, password, '/api/sessions' ) if @cookie.nil?

    # if ref is a url then use that one instead
    unless ref.nil?
      url = ref if ref.include?('http')
    end
    url ||= "https://#{servername}"+"#{ref}"

    headers = {}
    headers[:content_type] = content_type
    headers[:accept] = accept
    headers[:content_length] = 0
    headers[:x_vcloud_authorization] = @cookie

    params = {}
    params[:method] = action
    params[:url] = url
    params[:user] = username
    params[:password] = password
    params[:headers] = headers

    if content_type == :json
      params[:payload] = JSON.generate(body) if body
    else
      params[:payload] = body if body
    end
    log(:info, "Calling vCloud: #{url} action: #{action} payload: #{params[:payload]}")

    response = RestClient::Request.new(params).execute
    unless response.code == 200 || response.code == 201 || response.code == 202
      raise "Failure vCloud Response: #{response.code}"
    end
    # use XmlSimple to convert xml to ruby hash
    response_hash = XmlSimple.xml_in(response)
    return response_hash
  end

  log(:info, "CFME Automate Method Started", true)

  # dump all root attributes to the log
  dump_root()

  power_function = $evm.root['dialog_vcloud_operation']
  url = $evm.root['dialog_vcloud_vm']

  case power_function
  when 'on'
    href  = "#{url}"+"/power/action/powerOn"
  when 'off'
    href  = "#{url}"+"/power/action/powerOff"
  end

  log(:info, "Powering #{power_function} vCloud VM}")
  power_response = call_vcloud(:post, href, :xml, 'application/*+xml;version=5.1' )
  log(:info, "Inspecting power_response: #{power_response.inspect}")

  # Exit method
  log(:info, "CFME Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
