###################################
#
# EVM Automate Method: Remedy_Change_Query_Service
#
# Notes: Query Remedy Change Management Work Details
#
# Inputs:
#
###################################
begin
  @method = 'Remedy_Change_Query_Service'
  $evm.log("info","#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  #
  # Method: remedy_ChangeQueryService
  #
  def remedy_ChangeQueryService(wsdl_uri, username, password, change_id)
    # Require Savon Ruby Gem
    require 'savon'
    require 'httpi'

    HTTPI.log_level = :info
    HTTPI.log       = false

    # Set up SOAP Connection to WSDL
    client = Savon::Client.new do |wsdl|
      wsdl.document = wsdl_uri
    end

    $evm.log("info","#{@method} - Namespace: #{client.wsdl.namespace.inspect}") if @debug
    $evm.log("info","#{@method} - Endpoint: #{client.wsdl.endpoint.inspect}") if @debug
    $evm.log("info","#{@method} - Actions: #{client.wsdl.soap_actions.inspect}") if @debug

    # Call Remedy
    ars_response = client.request :change_query_service do
      # Build the xml header with credentials
      soap.header  = { 'AuthenticationInfo' => {
                         'userName' => username,
                         'password' => password,
                       :order!    => ['userName', 'password'] }
                       }

      # Build the body of the XML elements using the correct order
      soap.body = {
        # Get value from provisioning object (Mandatory Remedy field)
        'Infrastructure_Change_ID' => change_id
      }
    end
    return ars_response.to_hash
  end


  #
  # Method: build_request
  #
  def build_request(comment_hash)

    # Get the current logged in user
    user = $evm.root['user']
    #$evm.log("info","#{@method} - Inspecting User object:<#{user.inspect}>") if @debug

    if user.nil?
      userid = 'admin'
      user_mail = 'evmadmin@miq.net'
    else
      userid = user.userid
      user_mail = user.email
      # If currently logged in user email is nil assign a default email address
      user_mail ||= 'evmadmin@miq.net'
    end


    # arg1 = version
    args = ['1.1']
    # arg2 = templateFields
    args << "name=#{comment_hash[:template_name]}|request_type=template"
    # arg3 = vmFields
    #args << 'vm_name=automate_test|request_type=template|number_of_vms=1'
    args << "number_of_cpus=#{comment_hash[:number_of_cpus]}|vm_memory=#{comment_hash[:vm_memory]}|number_of_cores=#{comment_hash[:number_of_cores]}"
    # arg4 = requester
    args << "user_name=#{userid}|owner_email=#{user_mail}"
    # arg5 = tags
    args << 'lifecycle=retire_full'
    # arg6 = WS Values
    args << comment_hash.collect{|k,v| "#{k}=#{v}"}.join('|')
    # arg7 = emsCustomAttributes
    args << nil
    # arg8 = miqCustomAttributes
    args << nil

    $evm.log("info","#{@method} - Building provisioning request with the following arguments: <#{args.inspect}>") if @debug
    # exit MIQ_ABORT
    $evm.execute('create_provision_request', *args)
  end

  # Get variables
  #prov   = $evm.root['miq_provision']

  # Set Remedy wsdl loation
  wsdl_uri = nil
  wsdl_uri ||= $evm.object['wsdl_uri']

  # Set Remedy Variables
  username = nil
  username ||= $evm.object['username']

  password = nil
  password ||= $evm.object.decrypt('password')

  change_id = nil
  change_id ||= $evm.root['change_id']

  # Query Remedy Change
  $evm.log("info","#{@method} - Querying Remedy Change Request <#{change_id}>")

  remedy_query_results = remedy_ChangeQueryService(wsdl_uri, username, password, change_id)
  raise "#{@method} - Remedy returned no results" if remedy_query_results.nil?
  $evm.log("info","#{@method} - Inspecting remedy_query_results from Remedy:<#{remedy_query_results.inspect}>") if @debug

  comment_hash = {}

  # Get the notes field from Remedy and stuff it into comment_hash
  notes = remedy_query_results[:change_query_service_response][:notes]
  
  #Inspecting :notes from Remedy:<"OS=CentOS\nDisk=50GB\nRAM=1GB\nCPU=1">
  
  $evm.log("info","#{@method} - Inspecting :notes from Remedy:<#{notes.inspect}>") if @debug

  notes.split("\n").each do |str|
    
    # Strip out all whitespaces and build an array splitting on the '=' sign
    sp    = str.gsub(/\s/,'').split("=").compact
    
    # Assign the first element in the array to key
    key   = sp.first

    # Assign the last element in the array to key
    value = sp.last

    # Strip out the GB from the notes field
    comment_hash[key] = value.gsub(/GB/,'')
  end

  if comment_hash['OperatingSystem'].include?('Windows') 
    comment_hash['OperatingSystem'] = comment_hash['OperatingSystem'].gsub('dows','') 
  end
      
  comment_hash[:template_name] = "#{comment_hash['OperatingSystem']}_#{comment_hash['DiskSpace']}"
  comment_hash[:number_of_cpus] = '1'
  comment_hash[:number_of_cores] = comment_hash['CPU']
  comment_hash[:vm_memory] = comment_hash['Memory']

  # Map incoming vram GB Values to MB values for vm_memory variable
  vram_key = {"1"=>"1024","2"=>"2048","4"=>"4096","8"=>"8192", "16"=>"16384"}
  comment_hash[:vm_memory] = vram_key[comment_hash['Memory']]

  $evm.log("info","#{@method} - Inspecting comment_hash from Remedy:<#{comment_hash.inspect}>") if @debug

  # Initiate VM Provision with comments from Remedy
  build_request(comment_hash)

  # Modify Remedy Change
  #remedy_modify_results = remedy_ChangeModifyService(username, password, change_id)
  #raise "#{@method} - Remedy returned no results" if remedy_modify_results.nil?
  #puts "#{@method} - Inspecting remedy_modify_results from Remedy:<#{remedy_modify_results.inspect}>" if @debug

  # Get all comments from the results
  #remedy_getlistvalues = remedy_results[:change_modify_service_response][:request_id]
  #raise "#{@method} - Unable to get list values from Remedy" if remedy_getlistvalues.nil?
  #$evm.log("info","#{@method} - Inspecting remedy_getlistvalues: #{remedy_getlistvalues.inspect}") if @debug

  #ars_response = call_remedy(comment,subject,submitter,parent_id)
  #$evm.log("info","#{@method} - Inspecting ars_response: <#{ars_response}>")

  #
  # Exit method
  #
  $evm.log("info","#{@method} - EVM Automate Method Ended")


  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("info","#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
