begin

  def log(level, msg)
    @method = 'listLoadBalancers'
    $evm.log(level, "#{@method}: #{msg}")
  end

  def list_load_balancers(conn)
    res = conn.list_lb_pools.body['pools']
    log(:info, "List_LB_POOLS: #{res.inspect}")
    return res
  end


  gem 'fog', '>=1.22.0'
  require 'fog'

  name = nil

  name = $evm.object['ems_openstack_name']
  vm = $evm.root['vm']
  openstack = vm.ext_management_system


  raise "No openstack EMS found" if openstack.nil?

  tenant = $evm.object['tenant']
  tenant = 'admin' if tenant.nil?
  conn = Fog::Network.new({
    :provider => 'OpenStack',
    :openstack_api_key => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
    :openstack_tenant => tenant
  })

  load_balancers = list_load_balancers(conn)
  lb_hash = {}
  for lb in load_balancers
    lb_hash["#{lb['name']}"] = "#{lb['id']}"
  end

  lb_hash[nil] = nil

  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object["values"] = lb_hash
  $evm.object["default_value"] = lb_hash.first[0]
  log(:info, "Default is #{lb_hash.first[1]}")
  log(:info, "Dynamic drop down values: #{$evm.object['values']}")

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
