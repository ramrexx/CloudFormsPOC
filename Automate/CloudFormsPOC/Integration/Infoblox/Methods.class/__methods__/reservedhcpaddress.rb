###################################
#
# CFME Automate Method: ReserveDHCPAddress
#
# Author: Kevin Morey
#
# Notes: This method attempts to reserve a Infoblox DHCP Address
# gem requirements: 'rest_client', 'xmlsimple', 'json'
#
###################################
begin
  # Method for logging
  def log(level, msg, update_message=false)
    @method = 'ReserveDHCPAddress'
    $evm.log(level, "#{@method} - #{msg}")
    $evm.root['miq_provision'].message = "#{@method} - #{msg}" if $evm.root['miq_provision'] && update_message
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # call_infoblox
  def call_infoblox(action, ref='network', content_type=:xml, body=nil )
    require 'rest_client'
    require 'xmlsimple'
    require 'json'

    servername = nil || $evm.object['servername']
    username = nil || $evm.object['username']
    password = nil || $evm.object.decrypt('password')

    # if ref is a url then use that one instead
    url = ref if ref.include?('http')
    url ||= "https://#{servername}/wapi/v1.4.1/"+"#{ref}"

    params = {
      :method=>action,
      :url=>url,
      :user=>username,
      :password=>password,
      :headers=>{ :content_type=>content_type, :accept=>:xml }
    }
    content_type == :json ? (params[:payload] = JSON.generate(body) if body) : (params[:payload] = body if body)
    log(:info, "Calling -> Infoblox: #{url} action: #{action} payload: #{params[:payload]}")
    response = RestClient::Request.new(params).execute
    raise "Failure <- Infoblox Response: #{response.code}" unless response.code == 200 || response.code == 201
    # use XmlSimple to convert xml to ruby hash
    response_hash = XmlSimple.xml_in(response)
    log(:info, "Inspecting response_hash: #{response_hash.inspect}")
    return response_hash
  end

  log(:info, "CFME Automate Method Started", true)

  # dump all root attributes to the log
  #dump_root()

  case $evm.root['vmdb_object_type']
  when 'miq_provision'
    prov = $evm.root['miq_provision']
    log(:info, "Provision: #{prov.id} Request: #{prov.miq_provision_request.id} Type: #{prov.type}")
    macaddr     = prov.get_option(:mac_address)
    vmname      = prov.get_option(:vm_target_name)
    dns_domain  = nil || $evm.object['dns_domain']
    view        = nil || $evm.object['view']
  when 'vm'
    vm          = $evm.root['vm']
    vmname      = vm.name
    macaddr     = vm.mac_addresses.first
    dns_domain  = nil || $evm.object['dns_domain']
    view        = nil || $evm.object['view']
  end
  log(:info, "Detected view: #{view} dns_domain: #{dns_domain}")

  # call infoblox to get a list of networks
  networks_response = call_infoblox(:get)
  raise "networks_response returned nil" if networks_response.nil?

  # build a hash of network views as the key and add the network CIDR and the _ref values
  networks_hash_by_network_view = {}
  networks_response['value'].each { |k| (networks_hash_by_network_view[k['network_view'][0]]||={})[k['network'][0]] = k['_ref'][0] }
  log(:info, "Inspecting networks_hash_by_network_view: #{networks_hash_by_network_view}")

  # Filter the networks for a particular view
  networks = networks_hash_by_network_view[view]
  raise "no networks found for view: #{infoblox_view}" if networks.nil?
  log(:info, "Inspecting network view: #{view} networks: #{networks}")

  # Loop through each network to find an available IP Address
  networks.each do |network_cidr,network_ref|
    fixedaddress_body_hash = {
      :name => "#{vmname}.#{dns_domain}",
      :ipv4addr => "func:nextavailableip:#{network_cidr},#{view}",
      :mac => macaddr,
      :comment => "CloudForms server acquired at #{Time.now}",
      :options => [ { :name => "domain-name", :num => 15, :use_option => true, :value => "#{dns_domain}", :vendor_class => "DHCP" } ]
    }
    fixedaddress_response = call_infoblox(:post, 'fixedaddress', :json, fixedaddress_body_hash )
    log(:info, "Inspecting fixedaddress_response: #{fixedaddress_response}")
    get_ip_info_response = call_infoblox(:get, fixedaddress_response)
    log(:info, "Inspecting get_ip_info_response: #{get_ip_info_response.inspect}")
    ipaddr = get_ip_info_response['ipv4addr'][0]
    unless $evm.root['miq_provision'].nil?
      prov.set_option(:ip_addr, ipaddr)
      log(:info, "Provisioning object updated {:ip_addr => #{prov.get_option(:ip_addr)}}", true)
    else
      log(:info, "Adding custom attribute {:infoblox_ip => #{ipaddr.to_s}} to VM: #{vm.name}", true)
      vm.custom_set(:infoblox_ip, ipaddr.to_s)
    end
    break
  end

  # Exit method
  log(:info, "CFME Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
