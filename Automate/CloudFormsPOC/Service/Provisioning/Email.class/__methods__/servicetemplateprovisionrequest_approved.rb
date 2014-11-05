#
# ServiceTemplateProvisionRequest_Approved.rb
#
# Description: This method is used to email the provision requester that the Service provisioning request has been approved
begin
  # emailrequester
  def emailrequester(miq_request, appliance)
    $evm.log(:info, "Requester email logic starting")

    # Get requester object
    requester = miq_request.requester

    # Get requester email else set to nil
    requester_email = requester.email || nil

    # Get Owner Email else set to nil
    owner_email = miq_request.options[:owner_email] || nil
    $evm.log(:info, "Requester email:<#{requester_email}> Owner Email:<#{owner_email}>")

    # if to is nil then use requester_email
    to = nil
    to ||= requester_email

    # If to is still nil use to_email_address from model
    to ||= $evm.object['to_email_address']

    # Get from_email_address from model unless specified below
    from = nil
    from ||= $evm.object['from_email_address']

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # Build subject
    subject = "Request ID #{miq_request.id} - Your Service provision request was Approved"

    # Build email body
    body = "Hello, "
    body += "<br>Your Service provision request was approved. If Service provisioning is successful you will be notified via email when the Service is available."
    body += "<br><br>Approvers notes: #{miq_request.reason}"
    body += "<br><br>To view this Request go to: <a href='https://#{appliance}/miq_request/show/#{miq_request.id}'>https://#{appliance}/miq_request/show/#{miq_request.id}</a>"
    body += "<br><br> Thank you,"
    body += "<br> #{signature}"

    # Send email
    $evm.log(:info, "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
    $evm.execute(:send_email, to, from, subject, body)
  end

  # emailapprover
  def emailapprover(miq_request, appliance)
    $evm.log(:info, "Requester email logic starting")

    # Get requester object
    requester = miq_request.requester

    # Get requester email else set to nil
    requester_email = requester.email || nil

    # If to is still nil use to_email_address from model
    to = nil
    to ||= $evm.object['to_email_address']

    # Get from_email_address from model unless specified below
    from = nil
    from ||= $evm.object['from_email_address']

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # Build subject
    subject = "Request ID #{miq_request.id} - Your Service provision request was Approved"

    # Build email body
    body = "Approver, "
    body += "<br>Service provision request received from #{requester_email} was approved."
    body += "<br><br>Approvers reason: #{miq_request.reason}"
    body += "<br><br>To view this Request go to: <a href='https://#{appliance}/miq_request/show/#{miq_request.id}'>https://#{appliance}/miq_request/show/#{miq_request.id}</a>"
    body += "<br><br> Thank you,"
    body += "<br> #{signature}"

    # Send email
    $evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
    $evm.execute(:send_email, to, from, subject, body)
  end

  # Get miq_request from root
  miq_request = $evm.root['miq_request']
  raise "miq_request missing" if miq_request.nil?
  $evm.log(:info, "Detected Request:<#{miq_request.id}> with Approval State:<#{miq_request.approval_state}>")

  # Override the default appliance IP Address below
  appliance = nil
  #appliance ||= 'evmserver.company.com'
  appliance ||= $evm.root['miq_server'].ipaddress

  # Email Requester
  emailrequester(miq_request, appliance)

  # Email Requester
  #emailapprover(miq_request, appliance)

rescue => err
  $evm.log("error", "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
