begin

  def log(level, msg)
    @method = 'createLoadBalancer'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def create_floating_ip(conn, public_network)
    val = conn.create_floating_ip(public_network)
    return val.body['floatingip']
  end

  def list_external_networks(conn)
    array = []
    for network in conn.networks
      array.push(network) if network.router_external
    end
    return array
  end

  def list_private_subnets(conn, tenant_id)
    return conn.networks.select {
      |network| network.tenant_id.to_s == "#{tenant_id}" && network.router_external == false
    }
  end

  def create_lb_pool(conn, subnet_id, protocol="HTTP", method="ROUND_ROBIN", name)
  	log(:info, "Entering method create_lb_pool")
    response = conn.create_lb_pool(subnet_id, protocol, method ,
       {
         :name => "#{name}",
         :description => "#{name} created by CloudForms at #{Time.now}"
       }
    )
    return response.body
  end

  def create_lb_health_monitor (conn, protocol, uri)
  	log(:info, "Entering method create_lb_health_monitor")
    response = conn.create_lb_health_monitor(
      "#{protocol}", 5, 30, 2, { :url_path => "#{uri}", :http_method => "GET" }
    )
    return response.body
  end

  def find_free_ip(conn, subnet)
  	log(:info, "Entering method find_free_ip")
    puts "Finding free ip in #{subnet.cidr}"
    cidrobj = NetAddr::CIDR.create("#{subnet.cidr}")
    log(:info, "CIDROBJ #{cidrobj.class} #{cidrobj.inspect}")
    used_ips = {}
    ports = conn.ports
    for port in ports
      fixed_ips = port.fixed_ips.first
      used_ips["#{fixed_ips['ip_address']}"] = 1 if fixed_ips['subnet_id'] == subnet.id
    end
    used_ips.each_pair { |k,v| log(:info, "Found used ip #{k} on #{subnet.cidr}") }

    all_ips = cidrobj.enumerate
    index = 1
    while index < all_ips.length
      _ip = all_ips[index]
      unless used_ips["#{_ip}"]
        unless index == all_ips.length
          log(:info, "Found free ip #{_ip}")
          return _ip
        end
      end
      index = index + 1
    end
    return nil
  end

  def create_lb_vip(conn, subnet_id, pool_id, protocol, protocol_port, address)
  	log(:info, "Entering method create_lb_vip")
    response = conn.create_lb_vip(subnet_id, pool_id, protocol, protocol_port,
       { :name => "vip_created_by_cloudforms", :address => address }
      )
    return response.body
  end

  def get_tenant
    tenant_ems_id = $evm.root['dialog_cloud_tenant']
    log(:info, "Found EMS ID of tenant from dialog: #{tenant_ems_id}")
    return tenant_ems_id if tenant_ems_id.nil?

    tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
    log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
    return tenant
  end

  log(:info, "Begin Automate Methd")
  dump_root

  gem 'fog', '>=1.22.0'
  require 'fog'
  require 'netaddr'

  # For now, let's just choose the first one.
  openstack = $evm.vmdb(:ems_openstack).all.first

  tenant = get_tenant

  raise "Tenant ID is NIL" if tenant.nil?

  log(:info, "Logging with with tenant: #{tenant.name}")
  netconn = Fog::Network.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant.name
  })

  #create pool

  pool_name = $evm.root['dialog_pool_name']
  subnet_id = $evm.root['dialog_subnet']
  protocol = nil || $evm.root['dialog_protocol']
  method = $evm.root['dialog_method']
  port = $evm.root['dialog_port']
  #monitoring_type = $evm.root['dialog_monitoring_type']
  monitoring_type = nil || $evm.root['dialog_monitoring_type']

  case "#{port}"
  when "80"
    monitoring_type = "HTTP"
    protocol = "HTTP"

  when "443"
    monitoring_type = "HTTPS"
    protocol = "HTTPS"

  else
    monitoring_type = "TCP"
    protocol = "TCP"
  end

  uri = $evm.root['dialog_uri']
  uri = "/" if uri.nil?
  floating_ip = $evm.root['dialog_floating_ip']

  log(:info, "Got Dialog Values")

   # Get the task object from root
  service_template_provision_task = $evm.root['service_template_provision_task']

  # List Service Task Attributes
  service_template_provision_task.attributes.sort.each { |k, v| log(:info, "#{@method} - Task:<#{service_template_provision_task}> Attributes - #{k}: #{v}")}

  # Get destination service object
  service = service_template_provision_task.destination
  log(:info,"#{@method} - Detected Service:<#{service.name}> Id:<#{service.id}>")

  networks = list_private_subnets(netconn, tenant.ems_ref)
  log(:info, "Found Private Networks in tenant #{tenant.name}: #{networks.inspect}")

  subnet = nil
  for tnet in networks
    subnet = tnet.subnets.first if tnet.subnets.first.id.to_s == subnet_id
  end

  log(:info, "Found subnet #{subnet}")

  #subnet = nil
  #for t_subnet in subnets
  #  subnet = t_subnet if "#{t_subnet.cidr}" == "#{subnet_id}"
  #end

  raise "Unable to locate subnet object from #{subnet_id}" if subnet.nil?

  service_template_provision_task.message = "Creating Load Balancer #{pool_name} in tenant #{tenant.name}"

  log(:info, "creating lb pool #{pool_name} on subnet #{subnet_id} using #{protocol}/#{method}")
  pool = create_lb_pool(netconn, subnet.id, protocol, method, pool_name)
  log(:info, "Created pool: #{pool.inspect}")

  log(:info, "Creating lb health monitor")
  monitor = create_lb_health_monitor(netconn, monitoring_type, uri)
  log(:info, "Created health monitor #{monitor}")

  next_free = find_free_ip(netconn, subnet)
  log(:info, "Next free  on #{subnet.name} is #{next_free}")
  vip = create_lb_vip(netconn, subnet.id, pool['pool']['id'], "#{protocol}", port, next_free)
  log(:info, "Created VIP: #{vip.inspect}")

  log(:info, "Associating Health Monitor")
  netconn.associate_lb_health_monitor(pool['pool']['id'], monitor['health_monitor']['id'])

  if floating_ip == "yes"
    log(:info, "creating floating ip")
    floatingip = create_floating_ip(netconn, list_external_networks(netconn).first.id)
    log(:info, "Floating returned #{floatingip['floating_ip_address']} #{floatingip.inspect}")

    log(:info, "Associating floating ip")
    netconn.associate_floating_ip(floatingip['id'], vip['vip']['port_id'])
    log(:info, "Floating IP associated #{floatingip.inspect} to #{vip.inspect}")
    service.name = "LBaaS #{pool_name}: #{floatingip['floating_ip_address']}"
  else
  	service.name = "LBaaS #{pool_name}: #{next_free}"
  end

  log(:info, "Created load balancer, health monitor and vip")

  service_template_provision_task.finished("Created LB '#{pool_name}' in tenant #{tenant.name} successfully")
  service.tag_assign("cloud_tenants/#{tenant.name}")
  begin
    service.custom_set("FLOATING_IP", floatingip['id']) if floating_ip == "yes"
    service.custom_set("POOL_ID", pool['pool']['id'])
    service.custom_set("MONITOR_ID", monitor['health_monitor']['id'])
    service.custom_set("VIP_ID", vip['vip']['id'])
  rescue => seterr
    log(:error, "Exception setting attributes on service #{seterr.class} [#{seterr}] #{seterr.backtrace.join("\n")}")
  end
  exit MIQ_OK
rescue => err
  log(:error, "Unexpected Exception: [#{err}]\n#{err.backtrace.join("\n")}")
  unless $evm.root['service_template_provision_task'].nil?
    $evm.root['service_template_provision_task'].finished("Unexpected error: #{err} [#{err}]")
    $evm.root['service_template_provision_task'].destination.remove_from_vmdb
  end
  exit MIQ_ABORT
end
