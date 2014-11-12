###################################
#
# EVM Automate Method: NetScaler_BindServiceGroup
#
# Notes: This method uses a SOAP/XML call to Citrix Netscaler to add a member to a service group.
#
###################################
# Method for logging
def log(level, message)
  @method = 'NetScaler_BindServiceGroup'
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
  # Inuts: username, password, wsdl_uri, soap_action, soap_body (in hash format)
  #
  #################################
  def callNetscaler(username, password, wsdl_uri, soap_action, body_hash)
    # Require Savon Ruby Gem
    require "rubygems"
    require "savon"
    require 'httpi'

    # Turn off HTTPI logging
    HTTPI.log_level = :debug # changing the log level
    HTTPI.log       = false
    HTTPI.adapter   = :net_http # [:httpclient, :curb, :net_http]

    # Turn off Savon logging
    Savon.configure do |config|
      config.log        = false
      config.log_level  = :debug      # changing the log level
    end


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
    return response.to_hash
  end

  # Get provisioning object from root
  prov = $evm.root['miq_provision']

  # If the provisioning object is not nil
  unless prov.nil?
    log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

    # Ensure that the vm, vm ipaddress is not nil and the vm ipaddress is not equal to the template ip address
    if prov.vm.nil? || prov.vm.ipaddresses.first.nil? || prov.vm.ipaddresses.first == prov.vm_template.ipaddresses.first
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = '1.minute'
      log(:info,"Waiting for VM to be available. Retrying in 60 seconds")
      exit MIQ_OK
    end
    ipaddr = prov.vm.ipaddresses.first
    log(:info,"Found VM:<#{prov.vm.name}> IP:<#{ipaddr}> found")

  else
    vm = $evm.root['vm']

    unless vm.nil?
      ipaddr = vm.ipaddresses.first
    end
    log(:info,"Found VM:<#{vm.name}> IP:<#{ipaddr}> found")

  end

  # Get options from model
  username = nil
  username ||= $evm.object['username']

  password = nil
  password ||= $evm.object.decrypt('password')

  wsdl_uri = nil
  wsdl_uri ||= $evm.object['wsdl_uri']

  port = nil
  port ||= $evm.object['port']

  servicegroupname = nil
  servicegroupname ||= $evm.object['servicegroupname']

  bindservicegroup_response = callNetscaler(username, password, wsdl_uri, :bindservicegroup, { 'servicegroupname' => servicegroupname, 'ip' => ipaddr, 'port' => port } )

  unless bindservicegroup_response.nil?
    rc = bindservicegroup_response[:bindservicegroup_response][:return][:rc]
    message = bindservicegroup_response[:bindservicegroup_response][:return][:message]

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
