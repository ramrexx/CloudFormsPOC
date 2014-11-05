begin

  def log(level, msg)
    @method = 'createHeatStack'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def parameters_to_hash(parameters)
    log(:info, "Generating hash from #{parameters}")
    array1 = parameters.split(";")
    hash = {}
    for item in array1
      key, value = item.split("=")
      hash["#{key}"] = "#{value}"
    end
    log(:info, "Returning parameter hash: #{hash.inspect}")
    return hash
  end

  def get_tenant
    tenant_ems_id = $evm.root['dialog_cloud_tenant']
    log(:info, "Found EMS ID of tenant from dialog: '#{tenant_ems_id}'")
    return nil if tenant_ems_id.blank?
    tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
    log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
    return tenant.name
  end

  log(:info, "Begin Automate Method")

  gem 'fog', '>=1.22.0'
  require 'fog'

  dump_root
  service_template_provision_task = $evm.root['service_template_provision_task']
  service = service_template_provision_task.destination
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")
  log(:info, "DEBUG: #{service_template_provision_task.inspect}")

  ct_id = $evm.root['dialog_template_body']
  raise "Customization Template ID is nil" if ct_id.blank?
  log(:info, "Got Customization Template ID #{ct_id}")

  ct = $evm.vmdb(:customization_template).find_by_id(ct_id)
  raise "Customization Template from #{ct_id} is nil" if ct.nil?
  log(:info, "Found Heat Template: #{ct.name} #{ct.id}")
  template_body = ct.script

  parameters = $evm.root['dialog_parameters']
  stack_name = $evm.root['dialog_stack_name']

  log(:info, "Service Tags: #{service.tags.inspect}")
  tenant = get_tenant
  if tenant.blank?
    tenant = service.tags.select { 
        |tag_element| tag_element.starts_with?("cloud_tenants/")
      }.first.split("/", 2).last rescue nil
    log(:info, "Set tenant to '#{tenant}' because get_tenant returned nothing")
  end
  if tenant.blank?
    tenant = service.custom_get("TENANT_NAME") if tenant.blank?
    log(:info, "Set tenant to '#{tenant}' because couldn't find tenant from tags")
  end



  log(:info, "Creating stack #{stack_name} in tenant #{tenant}")
  log(:info, "Body:\n#{template_body}")
  log(:info, "Parameters: #{parameters}")

  options = { 'template' => template_body }
  options['parameters'] = parameters_to_hash(parameters) unless parameters.blank?

  mid = $evm.root['dialog_mid']
  raise "Management System ID is nil" if mid.blank?

  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
  raise "OpenStack Management system with id #{mid} not found" if openstack.nil?
  log(:info, "EMS_Openstack: #{openstack.inspect}\n#{openstack.methods.sort.inspect}")
              
  log(:info, "Getting Fog Connection to #{openstack[:hostname]}")
  conn = nil
  begin
    conn = Fog::Orchestration.new({
      :provider => 'OpenStack',
      :openstack_api_key => openstack.authentication_password,
      :openstack_username => openstack.authentication_userid,
      :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
      :openstack_tenant => tenant
    })
  rescue => connerr
    log(:error, "Retryable connection error #{connerr}")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "30.seconds"
    exit MIQ_OK
  end

  log(:info, "Successfully connected to OpenStack EMS #{openstack.name} Orchestration Service in tenant #{tenant}")
 
  stack_props = conn.create_stack(stack_name, options).body['stack']
  # Get a Stack Object
  stack = conn.stacks.find_by_id(stack_props['id'])
  raise "Missing stack id #{stack_props['id']}" if stack.nil?
  log(:info, "Stack: #{stack.inspect}")
  log(:info, "Stack created: #{stack.stack_status}/#{stack.stack_status_reason}")
  service.name = "HEAT: #{stack.stack_name}"
  service.description = "#{stack_props['id']}"
  service_template_provision_task.set_option(:stack_id, stack_props['id'])
  service_template_provision_task.set_option(:mid, mid)
  service.custom_set("STACK_ID", stack_props['id'])
  service.custom_set("MID", mid)
  service.tag_assign("cloud_tenants/#{tenant}")

  location_tag = openstack.tags.select { 
        |tag_element| tag_element.starts_with?("location/")
         }.first.split("/", 2).last rescue nil
  service.tag_assign("location/#{location_tag}") unless location_tag.nil?

  log(:info, "Completed #{@method}")
  log(:info, "#{service_template_provision_task.inspect}")

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'Error'
  task = $evm.root['service_template_provision_task']
  unless task.nil?
    task.destination.remove_from_vmdb
  end
  log(:error, "Removing failed service from VMDB")
  exit MIQ_ABORT
end
