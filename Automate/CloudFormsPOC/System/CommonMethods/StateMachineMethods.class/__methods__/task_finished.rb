# task_finished.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: Update the final messages for the following state machines:
#  ['service_template_provision_task', 'miq_provision']
#
def log_and_update_message(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  @task.message = msg if @task && (update_message || level == 'error')
end

begin
  @task = $evm.root[$evm.root['vmdb_object_type']]

  # prefix the message with the appliance name (helpful in large environments)
  final_message = "#{$evm.root['miq_server'].name}: "

  case $evm.root['vmdb_object_type']
  when 'service_template_provision_task'
    final_message += "Service: #{@task.destination.name} Provisioned Successfully"
    unless @task.miq_request.get_option(:override_request_description).nil?
      @task.miq_request.description = @task.miq_request.get_option(:override_request_description)
    end
  when 'miq_provision'
    final_message += "VM: #{@task.get_option(:vm_target_name)} "
    final_message += "IP: #{@task.vm.ipaddresses.first} " if @task.vm && ! @task.vm.ipaddresses.blank?
    final_message += "Provisioned Successfully"
    override_request_description = @task.miq_request.get_option(:override_request_description) || ''
    override_request_description += "(#{final_message}) "
    @task.miq_request.set_option(:override_request_description, "#{override_request_description}")
  else
    final_message += $evm.inputs['message']
  end
  log_and_update_message(:info, "Final Message: #{final_message}", true)
  @task.miq_request.user_message = final_message
  @task.finished(final_message)

  # Set Ruby rescue behavior
rescue => err
  log_and_update_message(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
