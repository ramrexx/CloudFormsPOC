###################################
#
# CFME Automate Method: Check_EnterMaintenanceMode
#
# Author: Kevin Morey
#
# Notes: This method checks to ensure that the host is in maintenance mode
#
###################################
begin
  # Method for logging
  def log(level, msg, update_message=false)
    @method = 'Check_EnterMaintenanceMode'
    $evm.log(level, "#{@method} - #{msg}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # basic retry logic
  def retry_method(retry_time=1.minute)
    log(:info, "Waiting for #{retry_time} seconds for host to enter maintenance mode")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root()

  # Get host from root object
  host = $evm.root['host']

  log(:info, "Host: #{host.name} has Power State: #{host.power_state}")

  # retry method unless is in maintenance mode
  unless host.power_state == "maintenance"
    retry_method()
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
