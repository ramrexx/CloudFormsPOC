# vm_retire_extend.rb
# Kevin Morey
# 2014.10.21
# Description: This method is used to add 14 days to retirement date when target VM has a retires_on value and is not already retired
#

# Number of days to automatically extend retirement
vm_retire_extend_days = nil
vm_retire_extend_days ||= $evm.root['dialog_retire_extend_days'] || $evm.object['vm_retire_extend_days']
raise "ERROR - vm_retire_extend_days not found!" if vm_retire_extend_days.nil?

$evm.log(:info, "Number of days to extend: #{vm_retire_extend_days}")

vm = $evm.root['vm']

vm.attributes.each {|key,val| $evm.log(:info, "VM: #{vm.name} {#{key} => #{val.inspect}}") if key.starts_with?('retire')}

unless vm.retires_on.blank? || vm_retire_extend_days.to_i.zero?
  $evm.log(:info, "Extending retirement #{vm_retire_extend_days} days for VM: #{vm.name}")

  # Set new retirement date here
  vm.retires_on += vm_retire_extend_days.to_i

  vm.attributes.each {|key,val| $evm.log(:info, "VM: #{vm.name} {#{key} => #{val.inspect}}") if key.starts_with?('retire')}

  # Get VM Owner Name and Email
  owner_id = vm.evm_owner_id
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
  subject = "VM Retirement Extended for #{vm.name}"

  # Build email body
  body = "Hello, "
  body += "<br><br>The retirement date for your virtual machine: #{vm.name} has been extended to: #{vm.retires_on}."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"

  # Send email
  $evm.log(:info, "Sending email to #{to} from #{from} subject: #{subject}")
  $evm.execute('send_email', to, from, subject, body)
end
