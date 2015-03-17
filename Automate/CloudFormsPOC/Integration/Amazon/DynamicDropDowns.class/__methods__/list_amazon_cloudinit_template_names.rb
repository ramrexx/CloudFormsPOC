# list_amazon_cloudinit_template_names.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: list cloud-init customization template names
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level,"#{msg}")
    @task.message = msg if @task && update_message
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
  $evm.vmdb(:customization_template_cloud_init).all.each do |ct|
    next if ct.name.nil?
    if ct.name.downcase.start_with?("amazon")
      dialog_hash[ct.name] = ct.name
    end
  end

  if dialog_hash.blank?
    log(:info, "No customization templates found")
    dialog_hash[nil] = "< No customization templates found, Contact Administrator >"
  else
    #$evm.object['default_value'] = dialog_hash.first
    dialog_hash[nil] = '< choose a customization template >'
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
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
