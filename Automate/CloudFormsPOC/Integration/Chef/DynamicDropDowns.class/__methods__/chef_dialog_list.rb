#
# CFME Automate Method: Chef_Dialog_List
#
# Notes: This method uses a knife to list cookbooks, roles and recipes as needed
#        change the "chef_type" object variable to switch, "role" is the default
#        chef_type should match something that would work with "knife chef_type list"
#        Now supports chef environments (-E option), use the "chef_environment" object variable
#        
#
# Requirements: 
# 1. knife must be installed on the appliance 
#  a) wget -O - http://www.opscode.com/chef/install.sh | bash
# 2. knife.rb must be correctly configured (I.e. paths-to-pem files, etc...)
# Author: Dave Costakos
# 
###################################
begin
  # Method for logging
  def log(level, message)
    $evm.log(level, "#{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def run_linux_admin(cmd, timeout=10)
    require 'linux_admin'
    require 'timeout'
    begin
      Timeout::timeout(timeout) {
        log(:info, "Executing #{cmd} with timeout of #{timeout} seconds")
        result = LinuxAdmin.run(cmd)
        log(:info, "Inspecting output: #{result.output.inspect}")
        log(:info, "Inspecting error: #{result.error.inspect}") unless result.error.blank? 
        log(:info, "Inspecting exit_status: #{result.exit_status.inspect}")
        return result
      }
    rescue => timeout
      log(:error, "Error executing chef: #{timeout.class} #{timeout} #{timeout.backtrace.join("\n")}")
      return false
    end
  end

  def build_dialog(values)
    # sort_by: value / description / none
    #$evm.object["sort_by"] = "description"
    # sort_order: ascending / descending
    #$evm.object["sort_order"] = "ascending"
    # data_type: string / integer
    $evm.object["data_type"] = "string"
    # required: true / false
    $evm.object["required"] = "false"
    # default_value:
    #$evm.object["default_value"] = 'apache2'
    # set the values to the dialog_hash
    $evm.object['values'] = values
    log(:info, "Dynamic drop down values: #{$evm.object['values']}")
    return $evm.object['values']
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  chef_environment = $evm.object['chef_environment']
  chef_environment = "_default" if chef_environment.blank?

  chef_type = $evm.object['chef_type']
  chef_type = "role" if chef_type.blank?

  log(:info, "Getting list of Chef Roles")
  cmd = "/usr/bin/knife #{chef_type} list -E #{chef_environment}"
  result = run_linux_admin(cmd)
  dialog_hash = {}
  if result
    dialog_hash = {}
    first = nil
    result.output.split("\n").sort.each { |chef_role|
      first = chef_role unless first
      dialog_hash[chef_role] = chef_role
    }
    dialog_hash[nil] = "< choose one >"
    log(:info, "Inspecting Values: #{build_dialog(dialog_hash).inspect}")
  else
    $evm.object['values'] = { nil => "< ERROR: contact administrator >"}
  end


  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.object['values'] = { nil => "ERROR: #{err}, contact administrator"}
  exit MIQ_OK
end
