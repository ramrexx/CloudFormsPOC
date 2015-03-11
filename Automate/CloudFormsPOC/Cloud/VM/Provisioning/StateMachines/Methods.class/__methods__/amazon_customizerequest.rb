# amazon_customizerequest.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to find an appropriate customization template during a Amazon Provisioning task
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
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

  # Get provisioning object
  @task = $evm.root["miq_provision"]

  log(:info, "Provision:<#{@task.id}> Request:<#{@task.miq_provision_request.id}> Type:<#{@task.type}>")

  @template = @task.vm_template
  provider = @template.ext_management_system
  product  = @template.operating_system['product_name'].downcase rescue nil
  log(:info, "Template: #{@template.name} Provider: #{provider.name} Vendor: #{@template.vendor} Product: #{product}")

  ws_values = @task.options.fetch(:ws_values, {})
  tags = @task.get_tags || {}

  #search for cloud-init templates
  if @task.get_option(:customization_template_id).nil?
    log(:info, "@task.eligible_customization_templates: #{@task.eligible_customization_templates.inspect}")
    customization_template_search   = tags[:role] || tags[:function] rescue nil
    customization_template_search ||= ws_values[:customization_template_id] || @template.name
    customization_template   = @task.eligible_customization_templates.detect { |ct| ct.name.casecmp("Amazon_#{customization_template_search}")==0 }
    customization_template ||= $evm.vmdb(:customization_template_cloud_init).find_by_id(customization_template_search)
    customization_template ||= @task.eligible_customization_templates.detect { |ct| ct.name.casecmp(customization_template_search)==0 }
    if customization_template.blank?
      log(:info, "No matching customization templates found")
    else
      log(:info, "Found customization template name: #{customization_template.name} id: #{customization_template.id} Description: #{customization_template.description}")
      @task.set_customization_template(customization_template) rescue nil
      log(:info, "Provisioning object updated {:customization_template_id => #{@task.get_option(:customization_template_id).inspect}}")
      log(:info, "Provisioning object updated {:customization_template_script => #{@task.get_option(:customization_template_script).inspect}}")
    end
  else
    log(:info, "Customization template selected from dialog id: #{@task.options[:customization_template_id].inspect}")
  end

  # Log all of the provisioning options to the automation.log
  @task.options.each { |k,v| log(:info, "Provisioning Option Key: #{k.inspect} Value: #{v.inspect}") }

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  @task.finished("#{err}") if @task
  exit MIQ_ABORT
end
