begin

  @method = "#{$evm.object}:OpenStack_CatalogItemInitialization_ClusterBestFit"
  @nova_url = nil
  @token = nil
  @debug = false

  def log(level, msg)
  	$evm.log(level, "<#{@method}>: #{msg}")
  end

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}") }
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def authenticate(auth_url, username, password, tenant)
  	@nova_url = nil
  	@token = nil

  	log(:info, "Enter Method authenticate(#{auth_url}, #{username}, #{password}, #{tenant})")
  	require 'rest_client'
  	require 'json'

  	params = {
      :method => "POST",
      :url => auth_url,
      :headers => { :content_type => :json, :accept => :json }
  	}
  	payload = {
  	  :auth => {
  	  	:tenantName => tenant,
  	  	:passwordCredentials => {
  	  	  :username => username,
  	  	  :password => password
  	  	}
  	  }
  	}
  	params[:payload] = JSON.generate(payload)
  	
  	begin
  	  response = RestClient::Request.new(params).execute
  	rescue RestClient::Unauthorized => noauth
  	  log(:error, "Unable to authenticate to OpenStack using #{auth_url}, #{username}, #{password}")
  	  log(:error, "#{noauth.class} [#{noauth}] #{noauth.backtrace.join("\n")}")
  	  exit MIQ_ABORT
  	end

  	json = JSON.parse(response)
  	log(:info, "Auth Response Headers: #{response.headers.inspect}") if @debug
  	log(:info, "Response: #{JSON.pretty_generate(json)}") if @debug

  	@token = json["access"]["token"]["id"]
  	@nova_url = nil
    for catalog_item in json["access"]["serviceCatalog"]
      if catalog_item['type'] == "compute" 
        @nova_url = "#{catalog_item['endpoints'][0]['publicURL']}"
        log(:info, "Set nova url to #{@nova_url}")
      end
    end
    log(:info, "Exit Method authenticate(#{auth_url}, #{username}, #{password}, #{tenant})")
  end

  def get_hypervisor_details()
  	log(:info, "Entering get_hypervisor_details for #{@nova_url}")
  	require 'rest_client'
  	require 'json'

    params = {
      :method => "GET",
      :url => "#{@nova_url}/os-hypervisors/statistics",
      :headers => { :content_type => :json, :accept => :json, 'X-Auth-Token' => "#{@token}" }
    }
    response = RestClient::Request.new(params).execute
    json = JSON.parse(response)
    log(:info, "Hypervisor Details Response Headers: #{response.headers.inspect}") if @debug
    log(:info, "Hypervisor Details Response: #{JSON.pretty_generate(json)}") if @debug
  	return json['hypervisor_statistics']
  end

  log(:info, "Begin Automate Method")
  dump_root
  tenant_name = "admin"

  sort_by_value = $evm.object['sort_by_value']
  sort_by_value = "free_ram_mb" if sort_by_value.nil?

  # Get the task object from root
  service_template_provision_task = $evm.root['service_template_provision_task']

  # Get destination service object
  service = service_template_provision_task.destination
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")

  list = $evm.vmdb(:ems_openstack).all
  details_hash = {}
  for openstack in list
    log(:info, "Inspecting #{openstack[:hostname]} for Best Fit Analysis")
    authenticate("http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens", openstack.authentication_userid, openstack.authentication_password, tenant_name)
    details = get_hypervisor_details()
    details_hash["#{openstack.id}"] = details
    log(:info, "Hypervisor Details for #{openstack[:hostname]}: #{details.inspect}")
  end
  array = details_hash.sort_by {|_key, value| value["#{sort_by_value}"]}
  log(:info, "Array: #{array.inspect}")
  log(:info, "Best Fit based on #{sort_by_value} is #{array.last.first}: #{array.last.last.inspect}")
  service_template_provision_task.miq_request_tasks.each do |t|
    grandchild_tasks = t.miq_request_tasks
    grandchild_tasks.each do |gc|
      gc.set_option(:best_fit_ems_id, "#{array.last.first}")
    end
  end
  log(:info, "End Automate Method")

rescue => err
  log(:error, "ERROR #{err.class}: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
