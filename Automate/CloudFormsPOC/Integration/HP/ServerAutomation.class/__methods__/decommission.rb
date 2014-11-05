begin
  def log (level, msg)
    @method = 'decommission'
    $evm.log(level, "<#{@method}>: #{msg}")
  end

  require 'savon'
  require 'rubygems'
  require 'httpi'

  # BEGIN MAIN #
  log(:info, "Automate method beginning")
  HTTPI.log_level = :debug
  HTTPI.log = false
  HTTPI.adapter = :net_http

  Savon.configure do |config|
    config.log = false
    config.log_level = :debug
  end

  username = $evm.object['hpsa_username']
  password = $evm.object.decrypt('hpsa_password')
  servername = $evm.object['hpsa_servername']

  log(:info, "Creating SOAP service to #{servername} with #{username}/*****")
  urlServerService = "/osapi/com/opsware/server/ServerService"
  log(:info, "Create ServerService SOAP Object to https://#{servername}#{urlServerService}?wsdl")
  serverService = Savon::Client.new do |wsdl,http|
    wsdl.document = "https://#{servername}#{urlServerService}?wsdl"
    wsdl.endpoint = "https://#{servername}#{urlServerService}"
    http.auth.basic username, password
    http.auth.ssl.verify_mode = :none
  end

  vm = nil
  case $evm.root['vmdb_object_type']
    when 'vm'
      vm = $evm.root['vm']
      log(:info, "Got vm object from $evm.root['vm']")
    when 'miq_provision'
      vm = $evm.root['miq_provision'].vm
      log(:info, "Got vm object from $evm.root['miq_provision']")
  end
  raise "#{@method} - VM object not found" if vm.nil?
  $evm.log("info","#{@method} - VM Found:<#{vm.name}>")

  server_id = vm.custom_get("HPSA_server_id")
  if server_id.nil?
    log(:info, "Searching for #{servername} in HPSA using filter ServerVO.name CONTAINS #{vm.name}")
    response = serverService.request :find_server_refs do |soap|
      soap.body = {
        'filter' => {
           'expression' => "ServerVO.name CONTAINS \"#{vm.name}\"",
           'objectType' => nil
        }
      }
    end
    log(:info, "Got Response to find_server_refs: #{response.inspect}")
    ref = response.to_hash[:find_server_refs_response][:find_server_refs_return]
    details = response.to_hash[:multi_ref]
    log(:info, "Ref Details #{ref.inspect}")
    log(:info, "Details (multi_ref) #{details.inspect}")
    # Set the custom attribute
    server_id = details[:id]
    vm.custom_set("HPSA_server_id", server_id)
    log(:info, "vm.custom_set HPSA_server_id to #{server_id}")
  else
    log(:info, "Found HPSA_server_id #{server_id} on #{vm.name}")
  end

  log(:info, "Starting Decommission")
  response = serverService.request :decommission do |soap|
    soap.body = {
      :self => { :id => server_id }
    }
  end

  log(:info, "Decommission Response: #{response.inspect}")
  log(:info, " --> Decommmission Hash: #{response.to_hash.inspect}")

  log(:info, "Starting Remove")
  response = serverService.request :remove do |soap|
    soap.body = {
      :self => { :id => server_id }
    }
  end
  log(:info, "Remove Response: #{response.inspect}")
  log(:info, " --> Remove Hash: #{response.to_hash.inspect}")

  # nil these out just in case
  log(:info, "Setting HPSA custom properties to nil")
  vm.custom_set("HPSA_server_id", nil)
  vm.custom_set("HPSA_software_policy_id", nil)
  log(:info, "Automate method exiting")

rescue => err
  log(:error, "ERROR occurred [#{err}]\n#{err.backtrace.join('\n')}")
  exit MIQ_STOP
end
