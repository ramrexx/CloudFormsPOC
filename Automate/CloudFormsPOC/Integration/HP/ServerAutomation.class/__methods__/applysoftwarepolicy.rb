begin

  def log (level, msg)
    @method = 'applySoftwarePolicy'
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

  username = $evm.object['hpsa_username']
  password = $evm.object.decrypt('hpsa_password')
  servername = $evm.object['hpsa_servername']
  product  = vm.operating_system['product_name'].downcase
  if product.include?("linux")
    softwarepolicyname = $evm.object['linux_policyname']
  elsif product.include?("windows")
    softwarepolicyname = $evm.object['windows_policyname']
  else
    raise "<#{@method}> Unknown Software Policy for #{vm.name} #{product}"
  end
  log(:info, "Creating SOAP service to #{servername} with #{username}/***** with #{softwarepolicyname}")
  
  urlServerService = "/osapi/com/opsware/server/ServerService"
  urlSoftwareService = "/osapi/com/opsware/swmgmt/SoftwarePolicyService"

  
  software_component_policy = nil
  software_component_policy_id = nil
  tags = $evm.root['miq_provision'].get_tags rescue nil
  tags = vm.tags if tags.nil?
  unless tags.nil?
    log(:info, "Got tags #{tags.inspect} from miq_provision object")
    tags.each do |full_tag|
      tag_cat, tag_val = full_tag.split('/')
      next unless tag_cat == "software_component"
      case tag_val
        when 'apache'
          software_component_policy = 'Telnet'
        when 'jboss'
          software_component_policy = 'Telnet'
        when 'mysql'
          software_component_policy = 'Telnet'
        when 'oracle_db'
          software_component_policy = 'Telnet'
      end
      log(:info, "Got software policy '#{software_component_policy}'' from #{tag_cat}/#{tag_val}")
    end
    log(:info, "Got software policy '#{software_component_policy}'' from tags")
  end

  log(:info, "Create ServerService SOAP Object to https://#{servername}#{urlServerService}?wsdl")
  serverService = Savon::Client.new do |wsdl,http|
    wsdl.document = "https://#{servername}#{urlServerService}?wsdl"
    wsdl.endpoint = "https://#{servername}#{urlServerService}"
    http.auth.basic username, password
    http.auth.ssl.verify_mode = :none
  end

  log(:info, "Create SoftwarePolicyService SOAP Object to https://#{servername}#{urlSoftwareService}?wsdl")
  softwarePolicyService = Savon::Client.new do |wsdl,http|
    wsdl.document = "https://#{servername}#{urlSoftwareService}?wsdl"
    wsdl.endpoint = "https://#{servername}#{urlSoftwareService}"
    http.auth.basic username, password
    http.auth.ssl.verify_mode = :none
  end 
  
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
  vm.custom_set("HPSA_server_id", "#{server_id}")
  log(:info, "vm.custom_set HPSA_server_id to #{server_id}")
  
  

  # Get a ref to the Software Policy Service
  response = softwarePolicyService.request :find_software_policy_refs do |soap|
    soap.body = {
      'filter' => {
         'expression' => "SoftwarePolicyVO.name EQUAL_TO \"#{softwarepolicyname}\"",
         'objectType' => nil
      }
    }
  end
  log(:info, "Got response from find_software_policy_refs #{response.inspect}")
  pref = response.to_hash[:multi_ref]
  pdetails = response.to_hash[:find_software_policy_refs_response][:find_software_policy_refs_return]
  log(:info, "pref (multi_ref): #{pref.class} #{pref.inspect}")
  log(:info, "pdetails (return): #{pdetails.inspect}")

  # Set the HpSA Software Policy ID  
  policy_id = pref[:id]
  vm.custom_set("HPSA_software_policy_id", "#{policy_id}")

  # Get the additional software component policy to run
  unless software_component_policy.nil?
    log(:info, "Searching for additional Software Policy #{software_component_policy}")
    response = softwarePolicyService.request :find_software_policy_refs do |soap|
    soap.body = {
      'filter' => {
         'expression' => "SoftwarePolicyVO.name EQUAL_TO \"#{software_component_policy}\"",
         'objectType' => nil
      }
    }
    end
    log(:info, "Got response from find_software_policy_refs for #{software_component_policy} #{response.inspect}")
    software_component_policy_id = response.to_hash[:multi_ref][:id] rescue nil
    if software_component_policy_id.nil?
      log(:warn, "Unable to find Software Component HPSA Policy for #{software_component_policy}")
    else
      vm.custom_set("HPSA_software_component_policy_id", "#{software_component_policy_id}")
      vm.custom_set("HPSA_software_component_policy_name", "#{software_component_policy}")
    end
  end
  
  policy_array = [ { :item => { :id => policy_id } } ]
  policy_array.push( { :item => { :id => software_component_policy_id } } ) unless software_component_policy_id.nil?

  # Attach Policies
  for t_policy in policy_array
    begin
      log(:info, "Attaching policy #{t_policy.inspect} to #{server_id}")
      response = serverService.request :attach_policies do |soap|
        soap.body = {
          :self =>  { :id => server_id },
          :policies => t_policy,
          :attributes! => {
            :self => {
               'xsi:type' => "#{details[:"@xsi:type"]}",
               'xmlns:ns2' => "#{details[:"@xmlns:ns2"]}"
            },
            :policies => {
               'xsi:type' => "ns2:ArrayOf_tns10_SoftwarePolicyRef",
               'xmlns:ns2' => "#{details[:"@xmlns:ns2"]}"
            }
          }
       }
      end
      log(:info, "Attached SoftwarePolcies Response #{response.to_hash.inspect}")
    rescue => soap_err
      log(:warn, "ERROR occurred, failed to attach policy #{t_policy} [#{soap_err}]\n#{soap_err.backtrace.join('\n')}")
    end
  end

  # Now Remediate the Software Policy
  for t_policy in policy_array
    begin
      log(:info, "Remediating Software Policy #{t_policy.inspect} on #{server_id}")
      response = softwarePolicyService.request :start_remediate_now do |soap|
        soap.body = {
          :selves => t_policy,
          :attachables => [ { :item => { :id => server_id } } ],
          :attributes! => {
            :attachables => {
              'xsi:type' => "ns2:ArrayOf_tns4_ServerRef",
              'xmlns:ns2' => "#{pref[:"@xmlns:ns2"]}"
            }
          }
        }
      end
      log(:info, "Remediate Now Response for t_policy #{response.to_hash.inspect}")
    rescue => soap_err
      log(:warn, "ERROR occurred, failed to remediate policy #{t_policy} [#{soap_err}]\n#{soap_err.backtrace.join('\n')}")
    end
  end

  log(:info, "Automate method exiting")
  #END MAIN#
rescue => err
  log(:error, "ERROR occurred [#{err}]\n#{err.backtrace.join('\n')}")
  exit MIQ_STOP
end
