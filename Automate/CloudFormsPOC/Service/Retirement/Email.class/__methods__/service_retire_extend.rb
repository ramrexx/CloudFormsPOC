# service_retire_extend.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to add x days to retirement date when target Service has a retires_on value and is not already retired
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

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # Number of days to automatically extend retirement
  service_retire_extend_days = nil
  service_retire_extend_days ||= $evm.root['dialog_retire_extend_days'] || $evm.object['service_retire_extend_days']
  raise "ERROR - service_retire_extend_days not found!" if service_retire_extend_days.nil?

  log(:info, "Number of days to extend: #{service_retire_extend_days}")

  service = $evm.root['service']

  service.attributes.each {|k, v| log(:info, "Service: #{service.name} Attribute: #{k} = #{v.inspect}") }

  unless service.retires_on.blank? || service_retire_extend_days.to_i.zero?
    $evm.log(:info, "Extending retirement #{service_retire_extend_days} days for Service: #{service.name}")

    # Set new retirement date here
    service.retires_on += service_retire_extend_days.to_i

    service.attributes.each {|k, v| log(:info, "Service: #{service.name} updated {#{k} => #{v.inspect}}") if k.include?('retire') }

    # Get Service Owner Name and Email
    owner_id = service.evm_owner_id
    owner = $evm.vmdb('user', owner_id) unless owner_id.nil?

    # to_email_address from owner.email then from model if nil
    to = owner.email unless owner.nil?
    to ||= $evm.object['to_email_address']

    # Get from_email_address from model unless specified below
    from = nil
    from ||= $evm.object['from_email_address']

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # email subject
    subject = "Service Retirement Extended for #{service.name}"

    # Build email body
    body = "Hello, "
    body += "<br><br>The retirement date for your service: #{service.name} has been extended to: #{service.retires_on}."
    body += "<br><br> Thank you,"
    body += "<br> #{signature}"

    # Send email
    log(:info, "Sending email to #{to} from #{from} subject: #{subject}")
    $evm.execute('send_email', to, from, subject, body)
  end

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
