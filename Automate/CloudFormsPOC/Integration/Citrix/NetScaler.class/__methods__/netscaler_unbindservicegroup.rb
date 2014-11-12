###################################
#
# EVM Automate Method: NetScaler_UnBindServiceGroup
#
# Notes: This method uses a SOAP/XML call to Citrix Netscaler to remove a member from a service group
#
###################################
# Method for logging
def log(level, message)
  @method = 'NetScaler_UnBindServiceGroup'
  @debug = true
  $evm.log(level, "#{@method} - #{message}") if @debug
end

begin
  log(:info, "EVM Automate Method Started")


  #################################
  #
  # Method: callNetscaler
  # Notes: Create a SOAP call to Netscaler
  #
  # Inuts: soap_action, soap_body (in hash format)
  #
  #################################
  def callNetscaler(soap_action, body_hash)
    # Require Savon Ruby Gem
    require "rubygems"
    require "savon"
    require 'httpi'

    # Turn off HTTPI logging
    HTTPI.log_level = :debug # changing the log level
    HTTPI.log       = false
    HTTPI.adapter   = :net_http # [:httpclient, :curb, :net_http]

    # Setup Savon Configuration to turn off logging
    Savon.configure do |config|
      config.log        = false
      config.log_level  = :debug      # changing the log level
    end

    #log(:info,"Calling #{wsdl_uri} with user:<#{username}> and pass:<#{password}>")
    # Set up SOAP Connection to WSDL
    client = Savon::Client.new do |wsdl,http|
      wsdl.document = wsdl_uri
      http.auth.basic username, password
    end

    # log(:info,"Namespace: #{client.wsdl.namespace.inspect}")
    # log(:info,"Endpoint: #{client.wsdl.endpoint.inspect}")
    # log(:info,"Actions: #{client.wsdl.soap_actions.inspect}")

    login_response = client.request :login do |soap|
      soap.body = {
        'username' => username,
        'password' => password,
      }
    end

    # Set the HTTP Cookie in the headers for all future calls
    raise "login to Netscaler failed" if login_response.nil?
    client.http.headers["Cookie"] = login_response.http.headers["Set-Cookie"]

    # Call Netscaler with desired soap_action and body_hash
    log(:info, "Calling Netscaler with SOAP action:<#{soap_action}> with parameters:<#{body_hash.inspect}>")
    response = client.request soap_action do
      soap.body = body_hash
    end
    #log(:info,"#{soap_action}_response: #{response.to_hash.inspect}")
    return response.to_hash
  end

  # Get VM from root object
  vm = $evm.root['vm']

  raise "VM object not found" if vm.nil?
  ipaddr = vm.ipaddresses.first
  log(:info,"Found VM:<#{vm.name}> IP:<#{ipaddr}> found")

  # Get options from model
  port = nil
  port ||= $evm.object['port']

  servicegroupname = nil
  servicegroupname ||= $evm.object['servicegroupname']

  username = nil
  username ||= $evm.object['username']

  password = nil
  password ||= $evm.object.decrypt('password')

  wsdl_uri = nil
  wsdl_uri ||= $evm.object['wsdl_uri']

  unbindservicegroup_response = callNetscaler(username, password, wsdl_uri, :unbindservicegroup, { 'servicegroupname' => servicegroupname, 'ip' => ipaddr, 'port' => port } )

  unless unbindservicegroup_response.nil?
    rc = unbindservicegroup_response[:unbindservicegroup_response][:return][:rc]
    message = unbindservicegroup_response[:unbindservicegroup_response][:return][:message]

    if rc == "0"
      log(:info, "Netscaler SOAP action successfully completed with return code:<#{rc}> message:<#{message}>")
    else
      log(:info, "Netscaler SOAP action failed with return code:<#{rc}> message:<#{message}>")
    end
  end


  #
  # Exit method
  #
  log(:info, "EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  log(:info, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
