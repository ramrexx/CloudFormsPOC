# update_provision_status.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method upates the request's status
#
# Required inputs: status
#
begin
  def log_and_update_message(level, msg, update_message = false)
    $evm.log(level, "#{msg}")
    @task.message = msg if @task && (update_message || level == 'error')
  end

  @task   = $evm.root['miq_provision']
  status = $evm.inputs['status']

  # build message string
  updated_message  = "#{$evm.root['miq_server'].name}: "
  updated_message += "VM: #{@task.get_option(:vm_target_name)} "
  updated_message += "Step: #{$evm.root['ae_state']} "
  updated_message += "Status: #{status} "
  updated_message += "Message: #{@task.message}"

  case $evm.root['ae_status_state']
  when 'on_entry'
    @task.miq_request.user_message = updated_message[0..250]
  when 'on_exit'
    @task.miq_request.user_message = updated_message[0..250]
  when 'on_error'
    @task.miq_request.user_message = updated_message[0..250]
    
    # email the requester with the provisioning failure details
    $evm.instantiate('/Infrastructure/VM/Provisioning/Email/MiqProvision_Failure')
  end

  # Set Ruby rescue behavior
rescue => err
  log_and_update_message(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
