###################################
#
# CFME Automate Method: EmailStatus
#
# Author: Kevin Morey
#
# Notes: This method emails the user regarding the hosts power state
#
###################################
begin
    # Method for logging
    def log(level, msg, update_message=false)
        @method = 'EmailStatus'
        $evm.log(level, "#{@method} - #{msg}")
    end

    log(:info, "CFME Automate Method Started")

    host = $evm.root['host']

    # Override the default appliance IP Address below
    appliance = nil
    #appliance ||= 'evmserver.company.com'
    appliance ||= $evm.root['miq_server'].ipaddress

    # Get requester object
    user = $evm.root['user']

    # get users email address else get it from the model
    user.email.nil? ? (to = nil || $evm.root['to_email_address']) : (to = user.email)

    # Get from_email_address from model unless specified below
    from = nil || $evm.object['from_email_address']

    # Get signature from model unless specified below
    signature = nil || $evm.object['signature']

    # Set email subject
    subject = "Host: #{host.name} - has a power_state: #{host.power_state}"

    # Build email body
    body = "Hello, "
    body += "<br><br>Host Information:"
    body += "User: #{user.name}"
    body += "Hostname: #{host.hostname}"
    body += "IP Address: #{host.ipaddress}"
    body += "Provider: #{host.ext_management_system.name}"
    body += "Cluster: #{host.ems_cluster.name}"
    body += "Number of VMs:: #{host.vms.count}"
    body += "For more additional information: <a href='https://#{appliance}/host/show/#{host.id}'</a>"
    body += "<br><br> Thank you,"
    body += "<br> #{signature}"

    # Send email to requester
    log(:info, "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
    $evm.execute(:send_email, to, from, subject, body)

    # Exit method
    log(:info, "CFME Automate Method Ended")
    exit MIQ_OK

    # Set Ruby rescue behavior
rescue => err
    log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
    exit MIQ_STOP
end
