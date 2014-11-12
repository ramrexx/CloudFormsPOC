###################################
#
# EVM Automate Method: Remedy_SearchCommentByParentId
#
# Integration: Remedy Action Request System (ARS)
#
# Notes: Search Remedy Comments by Parent ID
#
# Inputs: $evm.root['parent_id']
#
# Outputs: $evm.root['remedy_comment'], $evm.root['remedy_comment_id']
#
###################################
begin
  @method = 'Remedy_SearchCommentByParentId'
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true


  #################################
  #
  # Method: call_remedy
  # Notes: Create a SOAP call to Remedy
  # Returns: Array of Remedy Comments
  #
  #################################
  def call_remedy(parent_id)
    # Require Savon Ruby Gem
    require "savon"

    # Setup Savon Configuration
    Savon.configure do |config|
      config.log        = false            # disable logging
      config.log_level  = :info      # changing the log level
    end

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
    client = Savon::Client.new do |wsdl, http|
      wsdl.document = wsdluri
      http.auth.ssl.verify_mode = :none
    end

    $evm.log("info","#{@method} - Namespace: #{client.wsdl.namespace.inspect}") if @debug
    $evm.log("info","#{@method} - Endpoint: #{client.wsdl.endpoint.inspect}") if @debug
    $evm.log("info","#{@method} - Actions: #{client.wsdl.soap_actions.inspect}") if @debug

    # Call Remedy
    remedy_results = client.request :search_comment_by_parent_id do
      # Build the xml header with credentials
      soap.header  = { 'AuthenticationInfo' => {
          'userName' => username,
          'password' => password,
          :order!    => ['userName', 'password']
        }
      }

      # Build the body of the XML elements using the correct order
      soap.body = {
        'Parent_ID' => parent_id
      }
    end
    # Return Remedy results as a hash
    return remedy_results.to_hash
  end


  # Get inbound payload
  parent_id = $evm.root['parent_id']
  raise "#{@method} - Required parameter 'parent_id' missing: #{parent_id.inspect}" if parent_id.nil?

  # Call Remedy to pull back a list of comments attached to a Parent_ID as a hash
  remedy_results = call_remedy(parent_id)
  raise "Remedy returned no results" if remedy_results.nil?
  $evm.log("info","#{@method} - Inspecting remedy_results from Remedy:<#{remedy_results.inspect}>") if @debug

  # Get all comments from the results
  remedy_getlistvalues = remedy_results[:search_comment_by_parent_id_response][:get_list_values]
  raise "#{@method} - Unable to get list values from Remedy" if remedy_getlistvalues.nil?
  $evm.log("info","#{@method} - Inspecting remedy_getlistvalues: #{remedy_getlistvalues.inspect}") if @debug

  if remedy_getlistvalues.kind_of?(Array)
    # Sort the comment values by comment_id in descending value
    sorted_values = remedy_getlistvalues.sort { |a,b| b[:comment_id].to_i <=> a[:comment_id].to_i }
    $evm.log("info","#{@method} - Inspecting Sorted Values: #{sorted_values.inspect}") if @debug
  else
    # Single Comment found, no sort necessary. Converting to an Array.
    sorted_values = []
    sorted_values << remedy_getlistvalues
  end

  sorted_values.each do |sv|
    comment = sv[:comment].gsub(/\r|\t|\s+|\n?/, "")
    comment_id = sv[:comment_id]

    # Set Regular Express to find matching comments
    regex = /^(###start###).*(###end###)$/i

    # if the regular expression successfully matches
    if regex =~ comment
      $evm.log("info","#{@method} - Processing comment ID: <#{comment_id}> with comment: <#{comment}>")

      # Stuff the remedy comment and comment_id strings into the root object
      $evm.root['remedy_comment'] = comment.to_s
      $evm.root['remedy_comment_id'] = comment_id.to_s
      $evm.log("info","#{@method} - Successfully processed remedy_comment_id:<#{$evm.root['remedy_comment_id']}> with remedy_comment: <#{$evm.root['remedy_comment']}>")
      break
    else
      #$evm.log("info","#{@method} - Skipping comment ID: <#{comment_id}> with comment: <#{comment}>") if @debug
    end
  end

  # Bail out if no comments are found to match regular expression
  raise "#{@method} - No Remedy comments matched regular expression" if $evm.root['remedy_comment'].nil?


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
