###################################
#
# CFME Automate Method: Chef_Dialog_CookBookList
#
# Notes: This method uses a kinfe wrapper to build a dynamic dialog that lists Chef cookbooks
#
# Requirements: 
# 1. knife must be installed on the appliance 
#  a) wget -O - http://www.opscode.com/chef/install.sh | bash
# 2. 
# 3. knife.rb must be correctly configured (I.e. paths-to-pem files, etc...)
# 3. 
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'Chef_CookBookList'
    $evm.log(level, "#{@method}: #{message}")
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
    log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  def run_linux_admin(cmd)
    require 'linux_admin'
    log(:info, "Executing #{cmd}")
    result = LinuxAdmin.run!(cmd)
    log(:info, "Inspecting output: #{result.output.inspect}")
    log(:info, "Inspecting error: #{result.error.inspect}") unless result.error.blank? 
    log(:info, "Inspecting exit_status: #{result.exit_status.inspect}")
    return result
  end

  def build_dialog(values)
    # sort_by: value / description / none
    $evm.object["sort_by"] = "description"
    # sort_order: ascending / descending
    $evm.object["sort_order"] = "ascending"
    # data_type: string / integer
    $evm.object["data_type"] = "string"
    # required: true / false
    $evm.object["required"] = "false"
    # default_value:
    $evm.object["default_value"] = 'apache2'
    # set the values to the dialog_hash
    $evm.object['values'] = values
    log(:info, "Dynamic drop down values: #{$evm.object['values']}")
    return $evm.object['values']
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  log(:info, "Getting list of Chef CookBooks")
  cmd = "/var/www/miq/knife_wrapper.sh cookbook list"
  result = run_linux_admin(cmd)

  cookbooks = result.output.split("\n")
  cookbook_arr = []
  cookbooks.each do |element|
    cookbook_arr.push(element.split(" ").first)
  end

  log(:info, "Inspecting CookBook Array:<#{cookbook_arr.inspect}>")
  build_dialog(cookbook_arr)

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
