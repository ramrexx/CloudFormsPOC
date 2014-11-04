#
# MenAndMice_Acquire_IPAddress
# Author: Dave Costakos (Red Hat)
#
require 'savon'
require 'rubygems'
require 'httpi'

begin

  # logging convenience method
  def log (level, msg) 
    @method = 'MenAndMice_Release_IPAddress'
    $evm.log(level, "#{@method}: #{msg}")
  end

  def get_session_id
    log(:info, "get_session_id: entering method")
    response = @client.request :login do |soap|
      soap.body = {
        'server' => @central,
        'loginName' => @username,
        'password' => @password
      }    
    end
    log(:info, "get_session_id: #{response.to_hash[:login_response]}")
    log(:info, "get_session_id: exiting method")
    return response.to_hash[:login_response][:session]
  end

  def get_dns_zoneref(zonename)
    log(:info, "get_dns_zoneref(#{zonename}): entering method")
    response = @client.request :get_dns_zones do |soap|
      soap.body = {
        'session' => @session,
        'filter' => "type:^Master$ name:^#{zonename}$"
      }
    end
    log(:info, "get_dns_zoneref(#{zonename}): Response Details #{response.to_hash[:get_dns_zones_response].inspect}")
    zone = response.to_hash[:get_dns_zones_response][:dns_zones][:dns_zone]
    log(:info, "get_dns_zoneref(#{zonename}): Got zone #{zone}")
    log(:info, "get_dns_zoneref(#{zonename}): exiting method")
    return zone[:ref]
  end

  def get_dns_record(zoneref, ipaddr)
    log(:info, "get_dns_record(#{zoneref},#{ipaddr}): entering method")
    filter = "#{filter} data:^#{ipaddr}$" unless ipaddr.nil?
    log(:info, "get_dns_record(#{zoneref},#{ipaddr}): Using filter #{filter}")
    response = @client.request :get_dns_records do |soap|
      soap.body = {
        'session' => @session,
        'dnsZoneRef' => zoneref,
        'filter' => filter,
      }
    end
    log(:info, "get_dns_record(#{zoneref},#{ipaddr}): #{response.to_hash[:get_dns_records_response].inspect}")
    return nil if response.to_hash[:get_dns_records_response][:total_results] == 0
    return nil if response.to_hash[:get_dns_records_response][:dns_records].nil?
    hash = response.to_hash[:get_dns_records_response][:dns_records][:dns_record]
    puts "response: #{hash.inspect}"
    if "#{hash.class}" == "Hash"
      return hash[:ref]
    else
      raise "Reponse is of type #{hash.class}, probably multiple DNS entries with this name"
    end
    return hash[:ref]
  end

  def remove_dns_record(ref)
    log(:info, "remove_dns_record(#{ref}): entering method")
    response = @client.request :remove_object do |soap|
      soap.body = {
        'session' => @session,
        'ref' => ref,
      }
    end
    log(:info, "remove_dns_record(#{ref}):DEBUG: #{response.to_hash[:remove_object_response]}")
    log(:info, "remove_dns_record(#{ref}): exiting method")
  end

  def logout
    log(:info, "logout: entering method")
    log(:info, "logout: Logging out #{@session}") unless @session.nil?
    if @client.nil? || @session.nil?
      log(:info, "logout: exiting method")
      return
    end
    response = @client.request :logout do |soap|
      soap.body = {
        'session' => @session
      }
    end
    @session = nil
    log(:info, "logout: exiting method")
  end

  # --- BEGIN MAIN -----#
  # setup the soap client
  @username = $evm.object['username']
  @password = $evm.object.decrypt('password')
  @central = $evm.object['central']
  @wsdl = $evm.object['wsdl']
  @client = nil
  @session = nil

  # configure HTTPI
  HTTPI.log_level = :info
  HTTPI.log = false
  HTTPI.adapter = :net_http

  # Configure Savon
  Savon.configure do |config|
    config.log = false
    config.log_level = :debug
  end

  @client = Savon::Client.new do |wsdl,http|
    wsdl.document = @wsdl
  end

  vm = $evm.root['vm']
  raise "VM Object is nil from $evm.root" if vm.nil?
  log(:info, "MAIN: got vm object #{vm.inspect}")

  @session = get_session_id
  zoneref = get_dns_zoneref("corplab.example.com.")

  unless vm.ipaddresses.blank?
    vm.ipaddresses.each do |ip|
      log(:info, "MAIN: releasing IP #{ip}")
      record = get_dns_record(zoneref, ip)
      remove_dns_record(record)
      log(:info, "MAIN: released DNS Record #{ip}")
    end
  else
    log(:info, "MAIN: vm.ipaddresses blank: #{vm.ipaddresses.inspect}")
  end

  log(:info, "Main: exiting main method")
  # --- END MAIN -----#
  exit MIQ_OK
rescue => err
  log(:error,"ERROR occured [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
ensure
  log(:info, "Ensuring logout occurs")
  logout unless @session.nil?
end
