###################################
#
# EVM Automate Method: Remedy_ReassignRFC
#
# Notes: Reassign Service Request in Remedy
#
# Inputs: prov
#
###################################
begin
  @method = 'Remedy_ReassignRFC'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  #
  # Method: call_remedy
  #
  def call_remedy(parent_id, group)
    # Require Savon Ruby Gem
    require "savon"

    # Override username from model by entering one below else set it to nil
    username = nil
    username ||= $evm.object['username']

    # Override password from model by entering one below else set it to nil
    password = nil
    password ||= $evm.object.decrypt('password')

    # Override password from model by entering one below else set it to nil
    wsdluri = nil
    wsdluri ||= $evm.object['wsdl_uri']

    # Set up SOAP Connection to WSDL
    client = Savon::Client.new do |wsdl|
      wsdl.document = wsdluri
    end

    $evm.log("info","#{@method} - Namespace: #{client.wsdl.namespace.inspect}") if @debug
    $evm.log("info","#{@method} - Endpoint: #{client.wsdl.endpoint.inspect}") if @debug
    $evm.log("info","#{@method} - Actions: #{client.wsdl.soap_actions.inspect}") if @debug

    # Build the body of the xml element
    #body  = {'changeID'=>parent_id, 'group'=>group, :order! => ['changeID', 'group']}

    # Call Remedy
    ars_response = client.request :reassign_sr_rfc do |soap|
      # Build the xml header with credentials
      soap.header  = { 'AuthenticationInfo' => {
          'userName' => username,
          'password' => password,
          :order!    => ['userName', 'password']
        }
      }

      # Build the body of the XML elements using the correct order
      soap.body = {
        'changeID' =>parent_id,
        'group'    =>group,
        :order!    => ['changeID', 'group']
      }
    end
    return ars_response
  end

  # Get provisioning object
  prov = $evm.root["miq_provision"]

  # Get OS Type from the template platform
  product  = prov.vm_template.operating_system['product_name']
  $evm.log("info","#{@method} - Source Product: <#{product}>") if @debug

  if prov.options.has_key?(:ws_values)
    ws_values = prov.options[:ws_values]
    parent_id = ws_values[:parent_id]
    if product.include?("Linux")
      group = 'LNX ADM'
    else
      group = 'REMEDY SUPP'
    end
  end

  # Call remedy with parms
  ars_response = call_remedy(parent_id, group)
  $evm.log("info","#{@method} - Inspecting ars_response: <#{ars_response}>") if @debug

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
