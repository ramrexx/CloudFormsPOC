begin

  def log(level, msg)
    @method = 'stackStatus'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def get_tenant
    tenant_ems_id = $evm.root['dialog_cloud_tenant']
    log(:info, "Found EMS ID of tenant from dialog: #{tenant_ems_id}")
    if tenant_ems_id.nil?
      log(:info, "Did not find dialog_cloud_tenant value, getting tenant value from tag")
      tenant_tag = service.tags.select { 
        |tag_element| tag_element.starts_with?("cloud_tenants/")
      }.first.split("/", 2).last rescue nil
      return tenant_tag
    end

    tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
    log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
    return tenant.name
  end

  log(:info, "Begin Automate Method")
  gem 'fog', '>=1.22.0'
  require 'fog'

  dump_root
  check_status = "CREATE_COMPLETE"
  fail_match = "FAILED"

  unless $evm.object['check_status'].nil?
    check_status = $evm.object['check_status']
    service_template_provision_task.set_option('check_status', $evm.object['check_status'])
  end
  service_template_provision_task = $evm.root['service_template_provision_task']
  service = service_template_provision_task.destination
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")
  log(:info, "DEBUG: #{service_template_provision_task.inspect}")

  mid = service_template_provision_task.get_option(:mid)
  stack_id = service_template_provision_task.get_option(:stack_id)
  tenant_tag = get_tenant


  log(:info, "MID: #{mid} Stack ID: #{stack_id} Tenant #{tenant_tag}")

  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
  raise "OpenStack Management system with id #{mid} not found" if openstack.nil?
           
  conn = nil   
  begin            
    conn = Fog::Orchestration.new({
      :provider => 'OpenStack',
      :openstack_api_key => openstack.authentication_password,
      :openstack_username => openstack.authentication_userid,
      :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
      :openstack_tenant => tenant_tag
    })
  rescue => connerr
    log(:error, "retryable connection error: #{connerr}")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "30.seconds"
    exit MIQ_OK
  end

  log(:info, "Successfully connected to OpenStack EMS #{openstack.name} Orchestration Service")
  stack = conn.stacks.find_by_id(stack_id)

  unless stack.nil?
    log(:info, "Found Stack #{stack.stack_status} #{stack.inspect}")
    if stack.stack_status == "CREATE_COMPLETE"
      service_template_provision_task.message = "SUCCESS: #{stack.stack_status}"
      service.custom_set("STATUS", "SUCCESS: #{stack.stack_status}")
      log(:info, "Stack is complete")
    elsif stack.stack_status == "CREATE_FAILED"
      log(:error, "Stack creation failed: #{stack.stack_status_reason} #{stack.inspect}")
      reason = stack.stack_status_reason
      inspected = "#{stack.inspect}"
      response = conn.delete_stack(stack.stack_name, stack.id)
      log(:error, "Deleted stack response #{response.inspect}")
      raise "Stack creation failed #{reason} #{inspected}"
    else
      service_template_provision_task.message = "IN PROGRESS #{stack.stack_status}"
      service.custom_set("STATUS", "IN PROGRESS #{stack.stack_status} #{Time.new.strftime("%I")} #{Time.now.min} #{Time.new.strftime("%p")}")
      log(:info, "Sleeping for 30 seconds")
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = "30.seconds"
      exit MIQ_OK
    end
  end

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  task = $evm.root['service_template_provision_task']
  unless task.nil?
    task.destination.remove_from_vmdb
  end
  log(:error, "Removing failed service from VMDB")
  exit MIQ_ABORT
end
