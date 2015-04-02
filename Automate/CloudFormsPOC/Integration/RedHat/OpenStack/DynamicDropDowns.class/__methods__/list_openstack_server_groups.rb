#
# Description: list_server_groups
#
def log(level, msg, update_message=false)
  $evm.log(level, "#{msg}")
end

def get_provider(provider_id=nil)
  $evm.root.attributes.detect { |k,v| provider_id = v if k.end_with?('provider_id') } rescue nil
  provider = $evm.vmdb(:ems_openstack).find_by_id(provider_id)
  log(:info, "Found provider: #{provider.name} via provider_id: #{provider.id}") if provider
  # set to true to default to the admin tenant
  use_default = true
  unless provider
    # default the provider to first openstack provider
    provider = $evm.vmdb(:ems_openstack).first if use_default
    log(:info, "Found openstack: #{provider.name} via default method") if provider && use_default
  end
  provider ? (return provider) : (return nil)
end

def get_tenant(tenant_category, tenant_id=nil)
  # get the cloud_tenant id from $evm.root if already set
  $evm.root.attributes.detect { |k,v| tenant_id = v if k.end_with?('cloud_tenant') } rescue nil
  tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_id)
  log(:info, "Found tenant: #{tenant.name} via tenant_id: #{tenant.id}") if tenant

  unless tenant
    # get the tenant name from the group tenant tag
    group = $evm.root['user'].current_group
    tenant_tag = group.tags(tenant_category).first rescue nil
    tenant = $evm.vmdb(:cloud_tenant).find_by_name(tenant_tag) rescue nil
    log(:info, "Found tenant: #{tenant.name} via group: #{group.description} tagged_with: #{tenant_tag}") if tenant
  end

  # set to true to default to the admin tenant
  use_default = true
  unless tenant
    tenant = $evm.vmdb(:cloud_tenant).find_by_name('admin') if use_default
    log(:info, "Found tenant: #{tenant.name} via default method") if tenant && use_default
  end
  tenant ? (return tenant) : (return nil)
end

def get_fog_object(ext_mgt_system, type="Compute", tenant="admin", auth_token=nil, encrypted=false, verify_peer=false)
  proto = "http"
  proto = "https" if encrypted
  require 'fog'
  begin
    return Object::const_get("Fog").const_get("#{type}").new({
      :provider => "OpenStack",
      :openstack_api_key => ext_mgt_system.authentication_password,
      :openstack_username => ext_mgt_system.authentication_userid,
      :openstack_auth_url => "#{proto}://#{ext_mgt_system[:hostname]}:#{ext_mgt_system[:port]}/v2.0/tokens",
      :openstack_auth_token => auth_token,
      :connection_options => { :ssl_verify_peer => verify_peer, :ssl_version => :TLSv1 },
       :openstack_tenant => tenant
      })
  rescue Excon::Errors::SocketError => sockerr
    raise unless sockerr.message.include?("end of file reached (EOFError)")
    log(:error, "Looks like potentially an ssl connection due to error: #{sockerr}")
    return get_fog_object(ext_mgt_system, type, tenant, auth_token, true, verify_peer)
  rescue => loginerr
    log(:error, "Error logging [#{ext_mgt_system}, #{type}, #{tenant}, #{auth_token rescue "NO TOKEN"}]")
    log(:error, "#{loginerr} #{loginerr.backtrace.join("\n")}")
    log(:error, "Returning nil")
  end
  return nil
end
 
def list_groups(nova_url, token)
  log(:info, "Entering method list_groups")
  require 'rest-client'
  require 'json'
  params = {
    :method => "GET",
    :url => "#{nova_url}/os-server-groups",
    :headers => { :content_type => :json, :accept => :json, 'X-Auth-Token' => "#{token}" }
  }
  response = RestClient::Request.new(params).execute
  json = JSON.parse(response)
  log(:info, "Full Response #{JSON.pretty_generate(json)}")
  log(:info, "Exiting method list_groups")
  return json['server_groups']
end

log(:info, "Begin Automate Method")

provider = get_provider()

tenant_category = $evm.object['tenant_category'] || 'tenant'
tenant = get_tenant(tenant_category)
tenant_name = tenant
tenant_name = tenant.name if tenant.respond_to?('name')

conn = get_fog_object(provider, "Compute", tenant_name)
token = conn.instance_variable_get(:@auth_token)
nova_url = conn.instance_variable_get(:@openstack_management_url)

groups = list_groups(nova_url, token)
log(:info, "All Groups: #{groups.inspect}")
dialog_hash = {}
groups.each { |group| dialog_hash[group["id"]] = "#{group["name"]} on #{provider.name}" }
dialog_hash[nil] = "< Choose >"
$evm.object['values'] = dialog_hash
log(:info, "Set Dialog Hash to #{dialog_hash.inspect}")
log(:info, "Automate Method Ended")
