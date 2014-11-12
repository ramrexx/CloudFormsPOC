###################################
#
# EVM Automate Method: querySRM
#
# Notes: Calls VMware SRM to query protected group information for a VM and then dynamically 
#  tags the vm based SRM information
# Inputs: $evm.root['vm']
#
###################################
begin
  @method = 'querySRM'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true


  #################################
  #
  # Method: callSRM
  # Notes: Create a SOAP call to VMware SRM
  #
  #################################
  def callSRM(soap_action, body_hash)
    # Require Savon Ruby Gem
    require "savon"
    require 'httpi'

    HTTPI.log_level = :debug # changing the log level
    HTTPI.log       = false
    HTTPI.adapter   = :net_http # [:httpclient, :curb, :net_http]

    # Setup Savon Configuration
    Savon.configure do |config|
      config.log        = false
      config.log_level  = :debug      # changing the log level
    end

    # Set username name below else use input from model
    username = nil
    username ||= $evm.object['username']

    # Set username name below else use input from model
    password = nil
    password ||= $evm.object.decrypt('password')

    # Set wsdluri below else use input from model
    srmserver = nil
    srmserver ||= $evm.object['srmserver']

    # Set srm_port below else use input from model
    srm_port = nil
    srm_port ||= $evm.object['srm_port']

    # Set srm_apiport below else use input from model
    srm_apiport = nil
    srm_apiport ||= $evm.object['srm_apiport']

    # Set up Savon client
    client = Savon::Client.new do |wsdl, http, wsse|
      wsdl.document = "https://#{srmserver}:#{srm_port}/srm.wsdl"
      wsdl.endpoint = "https://#{srmserver}:#{srm_apiport}/sdk/srm"
      http.auth.ssl.verify_mode = :none
    end

    #$evm.log("info","#{@method} - Namespace: #{client.wsdl.namespace.inspect}") if @debug
    #$evm.log("info","#{@method} - Endpoint: #{client.wsdl.endpoint.inspect}") if @debug
    #$evm.log("info","#{@method} - Actions: #{client.wsdl.soap_actions.inspect}") if @debug

    # SRM login
    login_response = client.request :srm_login_locale do
      soap.body = { '_this' => 'SrmServiceInstance', 'username' => username, 'password' => password }
    end
    raise "Failed to login to SRM Server:<#{srmserver}> error:<#{login_response.inspect}>" unless login_response.success?

    # Set the HTTP Cookie in the headers for all future calls
    client.http.headers["Cookie"] = login_response.http.headers["Set-Cookie"]
    $evm.log("info","#{@method} - Login to SRM Server:<#{srmserver}> successful")  if @debug


    # Call SRM with desired soap_action and body_hash
    $evm.log("info","#{@method} - Calling SRM:<#{srmserver}> SOAP action:<#{soap_action}> with parameters:<#{body_hash.inspect}>") if @debug
    srm_response = client.request soap_action do
      soap.body = body_hash
    end

    # SRM logout
    logout_response = client.request :srm_logout_locale do
      soap.body = { '_this' => 'SrmServiceInstance' }
    end
    $evm.log("info","#{@method} - Logout of SRM Server:<#{srmserver}> successful:#{logout_response.to_hash.inspect}")  if @debug
    return srm_response.to_hash
  end


  ######################################
  #
  # Method: tagVM
  #
  ######################################
  def tagVM( vm, category, single_value=true, tag )

    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.downcase.gsub(/\W/, '_')
    tag_name = tag.downcase.gsub(/\W/, '_')
    $evm.log("info", "#{@method} - Converted category name:<#{category_name}> Converted tag name: <#{tag_name}>") if @debug

    # if the category exists else create it
    unless $evm.execute('category_exists?', category_name)
      $evm.log("info", "#{@method} - Category <#{category_name}> doesn't exist, creating category") if @debug
      $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category}")
    end

    # if the tag exists else create it
    unless $evm.execute('tag_exists?', category_name, tag_name)
      $evm.log("info", "#{@method} - Adding new tag <#{tag_name}> in Category <#{category_name}>") if @debug
      $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag}")
    end

    # Tag VM with category/tag information
    unless vm.tagged_with?(category_name,tag_name)
      $evm.log("info", "#{@method} - Tagging VM with new <#{tag_name}> tag in Category <#{category_name}>") if @debug
      vm.tag_assign("#{category_name}/#{tag_name}")
    end
  end


  # Get a hash list of SRM Protection Groups
  list_protection_groups = callSRM(:list_protection_groups, { '_this' => 'SrmProtection' } )
  srm_protection_groups = list_protection_groups[:list_protection_groups_response][:returnval]

  # Setup Array of Protection Groups if only one is found
  srm_protection_groups = srm_protection_groups.to_a unless srm_protection_groups.kind_of?(Array)

  # Loop through each SRM Protection Group
  srm_protection_groups.each do |pg|
    $evm.log("info", "#{@method} - Processing Protection Group:<#{pg.inspect}>")
    list_associated_vms = callSRM(:list_associated_vms, { '_this' => pg } )
    pg_associated_vms = list_associated_vms[:list_associated_vms_response][:returnval]

    # Create Array of Protection Group's VMs if only one is found
    pg_associated_vms = pg_associated_vms.split unless pg_associated_vms.kind_of?(Array)

    pg_associated_vms.each do |pg_vm|
      vm_candidate = $evm.root['ext_management_system'].vms.detect { |v| v.ems_ref == pg_vm }
      next unless vm_candidate
      $evm.log("info","#{@method} - Found VM:<#{vm_candidate.name}> ems_ref:<#{vm_candidate.ems_ref}> Protection Group VM:<#{pg}")  if @debug

      get_vm_group = callSRM(:protection_group_query_vm_protection, { '_this' => pg, 'vms' =>  vm_candidate.ems_ref } )
      query_vm_protection = get_vm_group[:protection_group_query_vm_protection_response][:returnval]
      $evm.log("info","#{@method} - Query VM Protection:<#{query_vm_protection.inspect}>")  if @debug

      # List tag categories to process
      valid_tag_categories = [ :protection_group_name, :peer_state, :status, :state, :recovery_plan_names ]

      # Loop through all valid tag categories to fine a matching key in the query_vm_protection hash
      valid_tag_categories.each do |category|
        value       = query_vm_protection[category]
        next if value.nil?
        $evm.log("info","#{@method} - Processing Category:<#{category.to_s.inspect}> value(s):<#{value.inspect}>")  if @debug

        # If values is an array, create a multi-tag category
        if value.kind_of?(Array)
          value.each { |tagval| tagVM( vm_candidate, "srm_#{category.to_s}", false, tagval.to_s ) }
        else
          tagVM( vm_candidate, "srm_#{category.to_s}", true, value.to_s )
        end
      end # end valid_tag_categories.each do
    end # end pg_associated_vms.each do
  end # srm_protection_groups.each do


  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
