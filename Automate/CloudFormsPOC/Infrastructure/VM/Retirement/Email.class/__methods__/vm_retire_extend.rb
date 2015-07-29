# vm_retire_extend.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to add X days to retirement date when target VM has a retires_on value and is not already retired
#
def dump_vm_retirement_attributes
  @vm.attributes.each {|key,val| $evm.log(:info, "VM: #{@vm.name} {#{key}=>#{val.inspect}}") if key.starts_with?('retire')}
end

def from_email_address
  $evm.object['from_email_address']
end

def to_email_address
  owner = @vm.owner || $evm.vmdb(:user).find_by_id(@vm.evm_owner_id) || $evm.root['user']
  owner_email = owner.email || $evm.object['to_email_address']
  owner_email
end

def signature
  $evm.object['signature']
end

def subject
  "VM: #{@vm.name} retirement extended #{vm_retire_extend_days} days"
end

def body
  body = "Hello, "
  body += "<br><br>The retirement date for your virtual machine: #{@vm.name} has been extended to: #{@vm.retires_on}."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
  body
end

begin
  @vm = $evm.root['vm']
  dump_vm_retirement_attributes

  vm_retire_extend_days = ( nil || $evm.root['dialog_retire_extend_days'] || $evm.object['vm_retire_extend_days'] ).to_i
  exit MIQ_STOP if vm_retire_extend_days.zero?

  exit MIQ_STOP if @vm.retires_on.nil?

  $evm.log(:info, "Extending retirement #{vm_retire_extend_days} days for VM: #{@vm.name}")

  # Set new retirement date here
  @vm.retires_on += vm_retire_extend_days
  dump_vm_retirement_attributes

  # Send email
  $evm.log(:info, "Sending email to #{to} from #{from} subject: #{subject}")
  $evm.execute('send_email', to_email_address, from_email_address, subject, body)

rescue => err
  $evm.log(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
