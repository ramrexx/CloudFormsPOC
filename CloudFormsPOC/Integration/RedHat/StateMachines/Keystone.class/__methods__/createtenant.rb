
begin

  def log(level, msg)
    @method = 'createTenant'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def get_role_ids_for_heat(conn)
    roles = []
    conn.list_roles[:body]["roles"].each { |role|
      roles.push(role) if role["name"] == "admin" || role["name"] == "heat_stack_owner" || role["name"] == "_member_"
    }
    return roles
  end

    # process_tags - Dynamically create categories and tags
  def process_tags( category, category_description, single_value, tag, tag_description )
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.to_s.downcase.gsub(/\W/, '_')
    tag_name = tag.to_s.downcase.gsub(/\W/, '_')
    log(:info, "Converted category name:<#{category_name}> Converted tag name: <#{tag_name}>")
    # if the category exists else create it
    unless $evm.execute('category_exists?', category_name)
      log(:info, "Category <#{category_name}> doesn't exist, creating category")
      $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category_description}")
    end
    # if the tag exists else create it
    unless $evm.execute('tag_exists?', category_name, tag_name)
      log(:info, "Adding new tag <#{tag_name}> description <#{tag_description}> in Category <#{category_name}>")
      $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag_description}")
    end
  end

  log(:info, "Begin Automate Method")

  gem 'fog', '>=1.22.0'
  require 'fog'

  dump_root

  # Assumed to be running through a service catalog
  service_template_provision_task = $evm.root['service_template_provision_task']
  service = service_template_provision_task.destination
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")
  log(:info, "DEBUG: #{service_template_provision_task.inspect}")

  # Get the OpenStack EMS from dialog_mid or grab the first one if it isn't set
  mid = $evm.root['dialog_mid']
  openstack = nil
  unless mid.nil?
    openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
  else
    openstack = $evm.vmdb(:ems_openstack).all.first
  end

  log(:info, "Connecting to OpenStack EMS #{openstack[:hostname]}/#{mid}")
  conn = nil
  # Get a connection as "admin" to Keystone 
  begin
    conn = Fog::Identity.new({
      :provider => 'OpenStack',
      :openstack_api_key => openstack.authentication_password,
      :openstack_username => openstack.authentication_userid,
      :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
      :openstack_tenant => "admin"
    })
  rescue => connerr
    log(:error, "Retryable connection error #{connerr}")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "30.seconds"
    exit MIQ_OK
  end

  # Get the tenant name from "dialog_tenant_name" or generate a random string if it isn't there
  name = $evm.root['dialog_tenant_name']
  name = "cftenant#{rand(36**10).to_s(36)}" if name.blank?
  description = "CloudForms Automate Tenant will be #{name}"

  # Create the new tenant
  tenant = conn.create_tenant({
    :description => description,
    :enabled => true,
    :name => name
  })[:body]["tenant"]
  log(:info, "Successfully created tenant #{tenant.inspect}")

  # Get my keystone user information
  myuser = conn.list_users[:body]["users"].select { |user| user["name"] == "#{openstack.authentication_userid}" }.first
  log(:info, "Got my user information: #{myuser.inspect}")

  # In IceHouse, the user must be a member of the right roles for Heat to work,
  # get those role ids, then assign them to the user in the new tenant
  myroles = get_role_ids_for_heat(conn)
  log(:info, "Got Role IDs for Heat: #{myroles.inspect}")
  myroles.each { |role|
    conn.create_user_role(tenant["id"], myuser["id"], role["id"])
  }
  log(:info, "User Roles Applied: #{conn.list_roles_for_user_on_tenant(tenant["id"], myuser["id"]).inspect}")

  # Set some custom attrs on the service so we can clean up later easily
  service.custom_set("TENANT_ID", "#{tenant["id"]}")
  service.custom_set("TENANT_NAME", "#{tenant["name"]}")

  # Create a tenant tag for the service so we know where that is too.
  process_tags("cloud_tenants", "Cloud Tenants", false, tenant["name"], tenant["name"])
  service.tag_assign("cloud_tenants/#{tenant["name"]}")
  service.custom_set("STATUS", "Created Cloud Tenant #{tenant["name"]}")
  log(:info, "Tagged Service: #{service.tags.inspect}")

  # Initiate a Refresh of the EMS
  openstack.refresh

  log(:info, "End Automate Method")

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
