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
    @method = 'MenAndMice_Acquire_IPAddress'
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

  def get_rangeref(name)
    log(:info, "get_range_ref(#{name}): entering method")
    response = @client.request :get_ranges do |soap|
      soap.body = {
        'session' => @session,
        'filter' => "name:^#{name}$"
      }
    end
    log(:info, "get_rangeref(#{name}): response details #{response.to_hash[:get_range_response].inspect}")
    hash = response.to_hash[:get_ranges_response][:ranges]
    if hash.nil?
      log(:info, "get_rangeref(#{name}): ERROR, could not find range #{name}")
      log(:info, "get_range_ref(#{name}): exiting method")
      return nil
    end
    log(:info, "get_range_ref(#{name}): debug_hash[:range]: #{hash[:range].inspect}")
    return hash[:range][:ref]
  end

  def get_next_free(rangeref, start_address)
    log(:info, "get_next_free(#{rangeref}, #{start_address}): entering method")
    response = @client.request :get_next_free_address do |soap|
      soap.body = {
        'session' => @session,
        'rangeRef' => rangeref,
        'ping' => true,
        'startAddress' => start_address
      }
    end
    nextfree = response.to_hash[:get_next_free_address_response][:address]
    log(:info, "get_next_free(#{rangeref}, #{start_address}): found #{nextfree}")
    log(:info, "get_next_free(#{rangeref}, #{start_address}): exiting method")
    return nextfree
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

  def add_dns_record(zoneref, address, fqdn)
    log(:info, "add_dns_record(#{zoneref},#{address},#{fqdn}): entering method")
    response = @client.request :add_dns_record do |soap|
      soap.body = {
        'session' => @session,
        'saveComment' => "Added by CloudForm at #{Time.now}",
        'dnsRecord' => {
          'name' => fqdn,
          'ttl' => "3600",
          'data' => address,
          'enabled' => true,
          'type' => "A",
          'dnsZoneRef' => zoneref,
        }
      }
    end
    log(:info, "add_dns_record(#{zoneref},#{address},#{fqdn}): #{response.to_hash[:add_dns_record_response]}")
    log(:info, "add_dns_record(#{zoneref},#{address},#{fqdn}): exiting method")
    return response.to_hash[:add_dns_record_response][:ref]
  end

  def get_dns_record(zoneref, dnsname, ipaddr)
    log(:info, "get_dns_record(#{zoneref},#{dnsname},#{ipaddr}): entering method")
    shortname = dnsname.split('.').first
    filter = "name:^#{shortname}$"
    filter = "#{filter} data:^#{ipaddr}$" unless ipaddr.nil?
    log(:info, "get_dns_record(#{zoneref},#{dnsname},#{ipaddr}): Using filter #{filter}")
    response = @client.request :get_dns_records do |soap|
      soap.body = {
        'session' => @session,
        'dnsZoneRef' => zoneref,
        'filter' => filter,
      }
    end
    log(:info, "get_dns_record(#{zoneref},#{dnsname},#{ipaddr}): #{response.to_hash[:get_dns_records_response].inspect}")
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

  rest = (rand(5)+rand(40)).seconds
  log(:info,"Sleeping for #{rest} seconds")
  sleep rest

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

  # these should be actually calculated, putting these here
  # as placeholders now
  # hard coded for now
  default_zone = "corplab.example.com."
  prov = $evm.root['miq_provision']
  tags = prov.get_tags
  log(:info, "Prov tags <#{tags}>")


  # get the hostname (FQDN == hostname + default_zone)
  hostname = prov.get_option(:vm_target_hostname) || prov.get_option(:vm_target_name)
  raise ":vm_target_hostname is nil" if hostname.nil?
  fqdn = "#{hostname}.#{default_zone}"

  # Hard coded for now
  base_db = "/CompanyXYZ/Provisioning/Network_Info"

  vmware_network = prov.get_option(:vlan)
  log(:info, "Found vmware_network <#{vmware_network}>")
  network_instance_name = vmware_network.match(/v\d+$/i)
  log(:info, "Got Network Instance Name <#{network_instance_name}>")

  network_props = $evm.instance_find("#{base_db}/#{network_instance_name}")
  network_props = network_props["#{network_instance_name}"]

  raise "network properties is nil from #{base_db}/#{network_instance_name}" if network_props.nil?

  log(:info, "main: network_props #{network_props.inspect} from #{base_db}/#{network_instance_name}")

  network_name = network_props['rangename']
  submask = network_props['submask']
  gateway = network_props['gateway']
  dns1 = network_props['dns1']
  dns2 = network_props['dns2']
  # dns_domain = network_props['dns_domain']

  startAddress = network_props['startAddress']

  @session = get_session_id
  rangeref = get_rangeref(network_name)
  log(:info, "Main: rangeref => #{rangeref}")
  zoneref = get_dns_zoneref(default_zone)
  log(:info, "Main: zoneref => #{zoneref}")
  nextfree = get_next_free(rangeref, startAddress)
  log(:info, "Main: allocated nextfree IP #{nextfree}")
  record = get_dns_record(zoneref, "#{hostname}.#{default_zone}", nil)
  if record.nil?
    log(:info, "Main: confirmed #{hostname}.#{default_zone} does not exist")
    ref = add_dns_record(zoneref, nextfree, "#{hostname}.#{default_zone}")
    log(:info, "Main: successfully added #{hostname}.#{default_zone} to DNS #{ref}")
  else
    log(:info, "Main: ERROR found #{record.inspect} already in DNS")
    raise "#{hostname}.#{default_zone} already exsists in Men and Mice"
  end

  log(:info, "Main: setting provisining options")
  prov.set_option(:addr_mode, ["static", "Static"])
  prov.set_option(:ip_addr, "#{nextfree}")
  prov.set_option(:subnet_mask, submask)
  prov.set_option(:gateway, gateway)
  prov.set_option(:dns_servers, "#{dns1}, #{dns2}")
  #prov.set_option(:dns_domain, dns_domain)
  #prov.set_option(:dns_suffixes, $evm.object['dns_domain'])

  logout
  log(:info, "Main: exiting main method")
  # --- END MAIN -----#
  exit MIQ_OK
rescue => err
  log(:error,"ERROR occured [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
ensure
  log(:info, "Ensuring logout occurs")
  logout unless @session.nil?
end
