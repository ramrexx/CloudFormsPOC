###################################
#
# EVM Automate Method: Remedy_SubmitComment
#
# Notes: Submit Comments to Remedy
#
# Inputs: prov, prov[:submitComments]
#
###################################
begin
  @method = 'Remedy_SubmitComment'
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true

  #
  # Method: call_remedy
  #
  def call_remedy(comment, subject, submitter_name, parent_id)
    # Require Savon Ruby Gem
    require 'savon'
    require 'httpi'
    
    HTTPI.log_level = :info
    HTTPI.log       = false

    username = nil
    username ||= $evm.object['username']

    password = nil
    password ||= $evm.object.decrypt('password')

    #$evm.log("info","Username: #{username}  Password: #{password}")
    #credentials   = { "wsdl:userName" => username, "wsdl:password" => password }

    # Set up SOAP Connection to WSDL
    client = Savon::Client.new do |wsdl|
      wsdl.document = nil
      wsdl.document ||= $evm.object['wsdl_uri']
    end

    $evm.log("info","#{@method} - Namespace: #{client.wsdl.namespace.inspect}") if @debug
    $evm.log("info","#{@method} - Endpoint: #{client.wsdl.endpoint.inspect}") if @debug
    $evm.log("info","#{@method} - Actions: #{client.wsdl.soap_actions.inspect}") if @debug

    # Call Remedy
    ars_response = client.request :submit_comment do
      # Build the xml header with credentials
      soap.header  = { 'AuthenticationInfo' => {
          'userName' => username,
          'password' => password,
          :order!    => ['userName', 'password']
        }
      }

      # Build the body of the XML elements using the correct order
      soap.body = {
        'Comment'         => comment,
        'Comment_Subject' => subject,
        'Submitter_Name'  => submitter_name,
        'Parent_ID'       => parent_id,
        :order!           => ['Comment', 'Comment_Subject', 'Submitter_Name', 'Parent_ID']
      }
    end
    return ars_response
  end


  # Get variables
  prov   = $evm.root['miq_provision']

  # Set Remedy Variables
  submitComments = prov['submit_comments']
  comment = submitComments[:comment]
  subject = submitComments[:subject]
  submitter = submitComments[:submitter]
  parent_id = submitComments[:parent_id]

  # Call remedy with parms
  ars_response = call_remedy(comment,subject,submitter,parent_id)
  $evm.log("info","#{@method} - Inspecting ars_response: <#{ars_response}>")

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
