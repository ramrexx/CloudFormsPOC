# list_amazon_providers.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: List all Amazon Providers
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

  dialog_hash = {}

  $evm.vmdb(:ems_amazon).all.each { |ems|
    dialog_hash[ems.id] = ems.name
  }

  if dialog_hash.blank?
    log(:info, "No Providers Found, Contact Administrator")
    dialog_hash[nil] = "< No Providers Found, Contact Administrator >"
  else
    #$evm.object['default_value'] = dialog_hash.first
    dialog_hash[nil] = '< choose a provider >'
  end

  $evm.object['values'] = dialog_hash
  log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
  
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
