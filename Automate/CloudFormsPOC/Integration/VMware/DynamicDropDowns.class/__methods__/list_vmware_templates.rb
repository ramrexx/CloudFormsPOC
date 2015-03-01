# list_vmware_templates.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: Build Dialog of all vmware tempalate guids
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level,"#{msg}")
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
  # build a hash of templates that meet this criteria
  $evm.vmdb(:template_vmware).all.each do |t|
    next if ! t.ext_management_system || t.archived
    dialog_hash[t[:guid]] = "#{t.name} on #{t.ext_management_system.name}" if t.tagged_with?(category, tag)
  end

  if dialog_hash.blank?
    log(:info, "No Templates found")
    dialog_hash[nil] = "< No Templates found >"
  else
    dialog_hash[nil] = '< choose a template >'
  end

  $evm.object["values"]     = dialog_hash
  log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "#{err.class} #{err}")
  log(:error, "#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
