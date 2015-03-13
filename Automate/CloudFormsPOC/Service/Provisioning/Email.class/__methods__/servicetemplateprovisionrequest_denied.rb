# ServiceTemplateProvisionRequest_Denied.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to email the requester and approver that the service request has been denied
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  def emailrequester(appliance, msg)
    log(:info, "Requester email logic starting")

    # Get requester object
    requester = @miq_request.requester

    # Get requester email else set to nil
    requester_email = requester.email || nil

    # Get Owner Email else set to nil
    owner_email = @miq_request.options[:owner_email] || nil
    log(:info, "Requester email: #{requester_email} Owner Email: #{owner_email}")

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
    subject = "Request ID #{@miq_request.id} - Your service request was denied"

    # Build email body
    body = "Hello, "
    body += "<br>#{msg}."
    body += "<br><br>Approvers notes: #{@miq_request.reason}"
    body += "<br><br>For more information you can go to: <a href='https://#{appliance}/miq_request/show/#{@miq_request.id}'>https://#{appliance}/miq_request/show/#{@miq_request.id}</a>"
    body += "<br><br> Thank you,"
    body += "<br> #{signature}"

    # Send email to requester
    log(:info, "Sending email to #{to} from #{from} subject: #{subject}")
    $evm.execute(:send_email, to, from, subject, body)
  end

  def emailapprover(appliance, msg)
    log(:info, "Approver email logic starting")

    # Get requester object
    requester = @miq_request.requester

    # Get requester email else set to nil
    requester_email = requester.email || nil

    # Get Owner Email else set to nil
    owner_email = @miq_request.options[:owner_email] || nil
    $evm.log(:info, "Requester email:<#{requester_email}> Owner Email:<#{owner_email}>")

    # Get requester email
    requester_email = requester_email || owner_email || $evm.object['to_email_address']

    ###
    to = nil
    to ||= $evm.object['to_email_address']

    # Override from_email_address below or get from_email_address from model
    from = nil
    from ||= $evm.object['from_email_address']

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # Set email subject
    subject = "Request ID #{@miq_request.id} - Virtual machine request was denied"

    # Build email body
    body = "Approver, "
    body += "<br>A service request received from #{requester_email} was denied."
    body += "<br><br>#{msg}."
    body += "<br><br>Approvers notes: #{@miq_request.reason}"
    body += "<br><br>For more information you can go to: <a href='https://#{appliance}/miq_request/show/#{@miq_request.id}'</a>"
    body += "<br><br> Thank you,"
    body += "<br> #{signature}"

    # Send email to approver
    $evm.log(:info, "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
    $evm.execute(:send_email, to, from, subject, body)
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # get the request object from root
  @miq_request = $evm.root['miq_request']
  log(:info, "miq_request id: #{@miq_request.id} approval_state: #{@miq_request.approval_state} options: #{@miq_request.options.inspect}")

  # lookup the service_template object
  service_template = $evm.vmdb(@miq_request.source_type, @miq_request.source_id)
  log(:info, "service_template id: #{service_template.id} service_type: #{service_template.service_type} description: #{service_template.description} services: #{service_template.service_resources.count}")

  # Override the default appliance IP Address below
  appliance = nil
  #appliance ||= 'evmserver.example.com'
  appliance ||= $evm.root['miq_server'].ipaddress

  # Get incoming message or set it to default if nil
  msg = @miq_request.resource.message || "Request denied"

  # Email Requester
  emailrequester(appliance, msg)

  # Email Approver
  emailapprover(appliance, msg)

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
