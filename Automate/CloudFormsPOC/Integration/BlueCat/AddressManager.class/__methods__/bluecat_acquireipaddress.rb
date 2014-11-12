###################################
#
# CFME Automate Method: BlueCat_AcquireIPAddress
#
# Notes: This method uses a SOAP/XML call to BlueCat Proteus to reserve an IP Address and
#  and set the values in the miq_provision object.
# - Gem requirements: savon -v 1.1.0
# - Inputs: $evm.root['miq_provision']
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'BlueCat_AcquireIPAddress'
    $evm.log(level, "#{@method} - #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def call_BlueCat(prov)
    # Require Ruby Gem
    gem 'savon', '=1.1.0'
    require "savon"
    require 'httpi'

    # Configure HTTPI gem
    HTTPI.log_level = :info # changing the log level
    HTTPI.log       = false # diable HTTPI logging
    HTTPI.adapter   = :net_http # [:httpclient, :curb, :net_http]

    # Configure Savon gem
    Savon.configure do |config|
      config.log        = false      # disable Savon logging
      config.log_level  = :fatal      # changing the log level
    end

    # Set servername below else use input from model
    #servername = 'proteus.example.com'
    servername = nil
    servername ||= $evm.object['servername']

    # Set username name below else use input from model
    #username = 'api_user'
    username = nil
    username ||= $evm.object['username']

    # Set username name below else use input from model
    #password = 'password'
    password = nil
    password ||= $evm.object.decrypt('password')

    # Set rootcontainer below else use input from model
    #rootcontainer = "MTC"
    rootcontainer = nil
    rootcontainer ||= $evm.object['rootcontainer']

    # Set gateway below else use input from model
    #gateway = '10.10.1.1'
    gateway = nil
    gateway ||= $evm.object['gateway']

    # Set subnet mask below else use input from model
    #submask = '255.255.255.0'
    submask = nil
    submask ||= $evm.object['submask']

    # Set up Savon client
    client = Savon::Client.new do |wsdl, http, wsse|
      wsdl.document = "http://#{servername}/Services/API?wsdl"
      wsdl.endpoint = "http://#{servername}/Services/API"
      http.auth.ssl.verify_mode = :none
    end

    log(:info, "Namespace:<#{client.wsdl.namespace}> Endpoint:<#{client.wsdl.endpoint}> Actions:<#{client.wsdl.soap_actions}>")

    # Log into BlueCat Proteus
    login_response = client.request :wsdl, :login do
      soap.body = {
        :username => username,
        :password => password,
        :order!    => [:username, :password],
      }
    end
    log(:info, "login:<#{login_response.inspect}>")

    # Set the HTTP Cookie in the headers for all future calls
    client.http.headers["Cookie"] = login_response.http.headers["Set-Cookie"]

    # Get system information from BlueCat Proteus to test the connection
    #system_info = client.request :wsdl, :get_system_info
    #log(:info, "System Info Response: #{system_info.to_hash[:get_system_info_response][:return].inspect}")

    getEntityByName = client.request :wsdl, :get_entity_by_name do
      soap.body = {
        :parent_id => 0,
        :name => rootContainer,
        :type => 'Configuration'
      }
    end
    #Get Entity By Name Response: {:type=>"Configuration", :name=>"MTC", :id=>"5", :properties=>nil}
    getEntityByName_hash = getEntityByName.to_hash[:get_entity_by_name_response][:return]
    log(:info, "Get Entity By Name Response: #{getEntityByName_hash.inspect}")

    container = getEntityByName_hash[:name]
    container_id = getEntityByName_hash[:id]
    $evm.log("info", "#{@log_prefix} - Container Name:<#{container}> ID:<#{container_id}>")

    getIPRangedByIP = client.request :wsdl, :get_ip_ranged_by_ip do
      soap.body = {
        :container_id => container_id,
        :address => gateway,
        :type => 'IP4Network'
      }
    end
    #Get IP Ranged By IP Response: {:type=>"IP4Network", :name=>"MTC", :id=>"77", :properties=>"CIDR=10.10.1.0/24|gateway=10.10.1.1|"}
    getIPRangedByIP_hash = getIPRangedByIP.to_hash[:get_ip_ranged_by_ip_response][:return]
    log(:info, "Get IP Ranged By IP Response: #{getIPRangedByIP_hash.inspect}")

    ip4network_id = getIPRangedByIP_hash[:id]
    log(:info, "IP4Network ID:<#{ip4network_id}>")
    properties_array = getIPRangedByIP_hash[:properties].split('|')
    cidr = properties_array.first
    log(:info, "CIDR:<#{cidr}>")

    getNextIP4Address = client.request :wsdl, :get_next_ip4_address do
      soap.body = {
        :parent_id => ip4network_id,
        :properties => 'excludeDHCPRange=true'
      }
    end
    $evm.log("info", "")
    log(:info, ":get_next_ip4_address response: #{getNextIP4Address.to_hash.inspect}")


    getNextIP4Address_hash = getNextIP4Address.to_hash[:get_next_ip4_address_response][:return]
    new_ipaddr = getNextIP4Address_hash
    log(:info, "Next IP 4 Address: #{new_ipaddr.inspect}")


    assignIP4Address = client.request :wsdl, :assign_ip4_address do
      soap.body = {
        :configuration_id => container_id,
        :ip4_address => new_ipaddr,
        :mac_address => '',
        :host_info => '',
        :action => 'MAKE_STATIC',
        :properties => ''
      }
    end
    log(:info, ":assign_ip4_address response: #{assignIP4Address.to_hash.inspect}")

    assignIP4Address_objid = assignIP4Address.to_hash[:assign_ip4_address_response][:return]
    log(:info, "Assigned Next IP 4 Address: #{assignIP4Address_objid.inspect}")

    # Log out of Proteus
    logout_response = client.request :wsdl, :logout
    log(:info, "logout: #{logout_response.inspect}")

    # Assign Networking information
    prov.set_nic_settings(0, {:ip_addr=>new_ipaddr, :subnet_mask=>submask, :gateway=>gateway, :addr_mode=>["static", "Static"]})
    log(:info, "Provision Object update: [:ip_addr=>#{prov.options[:ip_addr].inspect},:subnet_mask=>#{prov.options[:subnet_mask].inspect},:gateway=>#{prov.options[:gateway].inspect},:addr_mode=>#{prov.options[:addr_mode].last.inspect} ]")
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  # Get provisioning object
  prov = $evm.root['miq_provision']
  log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

  call_BlueCat(prov)

  # Exit method
  $evm.log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
