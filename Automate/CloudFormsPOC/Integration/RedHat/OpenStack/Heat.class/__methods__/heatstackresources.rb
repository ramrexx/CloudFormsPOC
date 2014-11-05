begin

  def log(level, msg)
    @method = 'heatStackResources'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}") }
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  log(:info, "Begin Automate Method")

  gem 'fog', '>=1.22.0'
  require 'fog'
  require 'rest_client'
  require 'json'


  dump_root
  service_template_provision_task = $evm.root['service_template_provision_task']
  service = service_template_provision_task.destination
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")
  log(:info, "DEBUG: #{service_template_provision_task.inspect}")

  mid = service_template_provision_task.get_option(:mid)
  stack_id = service_template_provision_task.get_option(:stack_id)
  tenant_tag = service.tags.select { 
    |tag_element| tag_element.starts_with?("cloud_tenants/")
    }.first.split("/", 2).last
  log(:info, "MID: #{mid} Stack ID: #{stack_id} in tenant #{tenant_tag}")

  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
  raise "OpenStack Management system with id #{mid} not found" if openstack.nil?
  log(:info, "Getting Fog Connection using '#{openstack.authentication_userid}'/'#{openstack.authentication_password}', 'http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens'")
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
    log(:error, "Retryable connection error #{connerr}")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "30.seconds"
    exit MIQ_OK
  end

  stack = conn.stacks.find_by_id(stack_id)
  raise "Stack is nil" if stack.nil?
  log(:info, "Found stack #{stack.inspect}")

  params = {
    :method => "POST",
    :url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :headers => { :content_type => :json, :accept => :json }
  }
  payload = {
    :auth => {
      :tenantName => tenant_tag,
      :passwordCredentials => {
        :username => openstack.authentication_userid,
        :password => openstack.authentication_password
      }
    }
  }
  params[:payload] = JSON.generate(payload) 
  response = RestClient::Request.new(params).execute
  json = JSON.parse(response)
  log(:info, "Rest auth response #{response.inspect}")
  log(:info, "Rest auth response headers #{response.headers.inspect}")

  # Get the Heat URL from the catalog
  heat_url = nil
  for catalog_item in json["access"]["serviceCatalog"]
    if catalog_item['type'] == "orchestration" 
      heat_url = "#{catalog_item['endpoints'][0]['publicURL']}"
    end
  end 

  token = json["access"]["token"]["id"]
  log(:info, "Authenticaiton Token: #{token}")

  params = {
    :method => "GET",
    :url => "#{heat_url}/stacks/#{stack.stack_name}/#{stack.id}/resources",
    :headers => { :content_type => :json, :accept => :json, 'X-Auth-Token' => "#{token}" }
  }

  response = RestClient::Request.new(params).execute
  json = JSON.parse(response)
  log(:info, "Stack resource response: #{json.inspect}")
  server_ids = []
  for resource in json['resources']
    log(:info, "On #{resource['resource_name']}")
    params = {
      :method => "GET",
      :url => "#{resource['links'][0]['href']}",
      :headers => { :content_type => :json, :accept => :json, 'X-Auth-Token' => "#{token}" }
    }
    puts "Params: #{params.inspect}"
    begin
      details = RestClient::Request.new(params).execute
      jdetails = JSON.parse(details)
      log(:info, "Response Details #{details.inspect}")
      log(:info, " --> #{jdetails['resource']['physical_resource_id']} #{jdetails['resource']['resource_type']}")
      case jdetails['resource']['resource_type']
        when "AWS::EC2::Instance"
          server_ids.push(jdetails['resource']['physical_resource_id'])
        when "OS::Nova::Server"
          server_ids.push(jdetails['resource']['physical_resource_id'])
      end
    rescue => reserr 
      log(:error, "Unable to get resurce #{resource['links'][0]['href']}")
      log(:error, "#{reserr.class} #{reserr} #{reserr.backtrace.join("\n")}")
      log(:error, "Continuing")
    end
  end
  log(:info, "Found server ids #{server_ids.inspect}")

  do_this_again = false
  for id in server_ids
    log(:info, "Finding server with ems_ref #{id} in vmdb")
    vm = $evm.vmdb('vm').all.detect { |instance| "#{instance.ems_ref}" == "#{id}" }
    if vm.nil?
      log(:info, "Server with id #{id} has not yet been discovered, retry required")
      do_this_again = true
    else
      log(:info, "Added vm #{vm.name} to #{service.name}")
      log(:info, "VM Add inspect: #{vm.inspect}")
      log(:info, "VM miq_provision: #{vm.miq_provision.inspect}") unless vm.miq_provision.nil?
      vm.add_to_service(service)
      vm.tag_assign("cloud_tenants/#{tenant_tag}")
      location_tag = nil
      location_tag = service.tags.select { 
        |tag_element| tag_element.starts_with?("location/")
         }.first.split("/", 2).last rescue nil
      vm.tag_assign("location/#{location_tag}") unless location_tag.blank?
      vm.refresh
    end
  end

  if do_this_again
    log(:info, "Retrying because not all resources have been discovered")
    begin
      openstack.refresh
      log(:info, "Initiated refresh of Openstack EMS sleeping")
    rescue => refresherr
      log(:error, "Unable to initiate refresh: #{refresherr}\n#{refresherr.backtrace.join("\n")}")
    end
    service_template_provision_task.message = "Waiting for CloudForms to discover all Resources in Stack"
    service.custom_set("STATUS", "COMPLETE, Waiting for CloudForms to discover all Resources in Stack")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "1.minute"
    exit MIQ_OK
  else
    log(:info, "All resources have been discovered")
    service_template_provision_task.finished("Stack Completed, All VMs Associated")
    service_template_provision_task.set_option(:twilio_message, "Heat Stack #{stack.stack_name} deployed successfully")
    service_template_provision_task.set_option(:twilio_phone, "+16198402579")
    service.custom_set("STATUS", nil)
  end

  exit MIQ_OK

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  task = $evm.root['service_template_provision_task']
  unless task.nil?
    task.finished("FINISHED with Error: #{err}")
  end
  log(:error, "Removing failed service from VMDB")
  exit MIQ_ABORT
end
