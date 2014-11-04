###################################
#
# CFME Automate Method: ServiceTemplateProvisionRequest_Pending
#
# Notes: This method is used to email the service requester that
# the Service request was not auto-approved
#
# Event: request_pending
#
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    requester does not have a valid email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@company.com,user@company.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'ServiceTemplateProvisionRequest_Pending'
    $evm.log(level, "#{@method} - #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # emailrequester
  def emailrequester(miq_request, appliance)
    log(:info, "Requester email logic starting")

    # Get requester object
    requester = miq_request.requester

    # Get requester email else set to nil
    requester_email = requester.email || nil

    # Get Owner Email else set to nil
    owner_email = miq_request.options[:owner_email] rescue nil
    log(:info, "Requester email:<#{requester_email}> Owner Email:<#{owner_email}>")

    # if to is nil then use requester_email or owner_email
    to = nil
    to ||= requester_email || owner_email || $evm.object['to_email_address']

    # Get from_email_address from model unless specified below
    from = nil
    from ||= $evm.object['from_email_address']

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # Set email subject
    subject = "Request ID #{miq_request.id} - Your Service Request was not Auto-Approved"

    # Build email body
    body = "Hello, "
    body += "<br><br>Please review your Request and wait for approval from an Administrator."
    body += "<br><br>To view this Request go to: "
    body += "<a href='https://#{appliance}/miq_request/show/#{miq_request.id}'>https://#{appliance}/miq_request/show/#{miq_request.id}</a>"
    body += "<br><br> Thank you,"
    body += "<br> #{signature}"
    
    # Send email
    log(:info, "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
    $evm.execute(:send_email, to, from, subject, body)
  end

  # emailapprover
  def emailapprover(miq_request, appliance)
    log(:info, "Requester email logic starting")

    # Get requester object
    requester = miq_request.requester

    # Get requester email else set to nil
    requester_email = requester.email || nil

    # Get Owner Email else set to nil
    owner_email = miq_request.options[:owner_email] || nil
    log(:info, "Requester email:<#{requester_email}> Owner Email:<#{owner_email}>")

    # Override to email address below or get to_email_address from from model
    to = nil
    to  ||= $evm.object['to_email_address']

    # Override from_email_address below or get from_email_address from model
    from = nil
    from ||= $evm.object['from_email_address']

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # Set email subject
    subject = "#{@method} - Request ID #{miq_request.id} - Virtual machine request was not approved"

    # Build email body
    body = "Approver, "
    body += "<br>A Service request received from #{requester_email} is pending."
    body += "<br><br>Approvers notes: #{miq_request.reason}" 
    body += "<br><br>For more information you can go to: <a href='https://#{appliance}/miq_request/show/#{miq_request.id}'>https://#{appliance}/miq_request/show/#{miq_request.id}</a>"
    body += "<br><br> Thank you,"
    body += "<br> #{signature}"

    # Send email
    log(:info, "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
    $evm.execute(:send_email, to, from, subject, body)
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  # get the request object from root
  miq_request = $evm.root['miq_request']
  log(:info, "miq_request id:<#{miq_request.id}> approval_state:<#{miq_request.approval_state} options[:dialog]:<#{miq_request.options[:dialog].inspect}>")

  # lookup the service_template object
  service_template = $evm.vmdb(miq_request.source_type, miq_request.source_id)
  log(:info, "service_template id:<#{service_template.id}> service_type:<#{service_template.service_type}> description:<#{service_template.description}> services:<#{service_template.service_resources.count}>")

  # Override the default appliance IP Address below
  appliance = nil
  #appliance ||= 'evmserver.company.com'
  appliance ||= $evm.root['miq_server'].ipaddress

  # Email Requester
  emailrequester(miq_request, appliance)

  # Email Requester
  emailapprover(miq_request, appliance)

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
