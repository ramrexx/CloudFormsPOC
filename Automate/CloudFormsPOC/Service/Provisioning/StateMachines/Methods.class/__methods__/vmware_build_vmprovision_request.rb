# vmware_build_vmprovision_request.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Uses: Simple method to kick off a provisioning request from the one of the following:
#  a) Generic Service Catalog Item that provisions one or many VMs into a service
#  b) Service Button for the purpose of provisioning VMs to an existing service
#  c) API driven for the purpose of provisioning VMs to an existing service or just provisioning new VMs without a service
#  d) VM driven from a button, Policy or Alert event for Flexing
#
# Description: This method Performs the following functions:
# 1. YAML load the Service Dialog Options from @task.get_option(:parsed_dialog_options))
# 2. Set the name of the service
# 3. Set tags on the service
# 5. Launch VMProvisionRequest with any options and tags
#
# Important - The dialog_parser automate method has to run prior to this in order to populate the dialog information.
#
# Inputs: dialog_option_[0-9]_template, dialog_option_[0-9]_flavor, dialog_tag_[0-9]_environment, etc...
#
def log_and_update_message(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  @task.message = msg if @task && (update_message || level == 'error')
end

# Loop through all tags from the dialog and create the categories and tags automatically
def create_tags(category, single_value, tag)
  log_and_update_message(:info, "Processing create_tags...", true)
  # Convert to lower case and replace all non-word characters with underscores
  category_name = category.to_s.downcase.gsub(/\W/, '_')
  tag_name = tag.to_s.downcase.gsub(/\W/, '_')

  # if the category exists else create it
  unless $evm.execute('category_exists?', category_name)
    log_and_update_message(:info, "Category #{category_name} doesn't exist, creating category")
    $evm.execute('category_create', :name         => category_name,
                 :single_value => single_value,
                 :description  => "#{category}")
  end
  # if the tag exists else create it
  unless $evm.execute('tag_exists?', category_name, tag_name)
    log_and_update_message(:info, "Adding new tag #{tag_name} in Category #{category_name}")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag}")
  end
  log_and_update_message(:info, "Processing create_tags...Complete", true)
end

def override_service_attribute(dialogs_options_hash, attr_name)
  service_attr_name = "service_#{attr_name}".to_sym

  log_and_update_message(:info, "Processing override_attribute for #{service_attr_name}...", true)
  attr_value = dialogs_options_hash.fetch(service_attr_name, nil)
  attr_value = "#{@service.name}-#{Time.now.strftime('%Y%m%d-%H%M%S')}" if attr_name == 'name' && attr_value.nil?

  log_and_update_message(:info, "Setting service attribute: #{attr_name} to: #{attr_value}")
  @service.send("#{attr_name}=", attr_value)

  log_and_update_message(:info, "Processing override_attribute for #{service_attr_name}...Complete", true)
end

def process_tag(tag_category, tag_value)
  return if tag_value.blank?
  create_tags(tag_category, true, tag_value)
  log_and_update_message(:info, "Assigning Tag: {#{tag_category} => tag: #{tag_value}} to Service: #{@service.name}")
  @service.tag_assign("#{tag_category}/#{tag_value}")
end

# service_tagging - tag the service with tags in dialogs_tags_hash[0]
def tag_service(dialogs_tags_hash)
  log_and_update_message(:info, "Processing tag_service...", true)

  # Look for tags with a sequence_id of 0 to tag the service
  dialogs_tags_hash.fetch(0, {}).each do |key, value|
    log_and_update_message(:info, "Processing tag: #{key.inspect} value: #{value.inspect}")
    tag_category = key.downcase
    Array.wrap(value).each do |tag_entry|
      process_tag(tag_category, tag_entry.downcase)
    end
  end
  log_and_update_message(:info, "Processing tag_service...Complete", true)
end

def dialog_parser_error
  log_and_update_message(:error, "Error loading dialog options")
  exit MIQ_ABORT
end

def yaml_data(option)
  @task.get_option(option).nil? ? nil : YAML.load(@task.get_option(option))
end

def parsed_dialog_information
  dialog_options_hash = yaml_data(:parsed_dialog_options)
  dialog_tags_hash = yaml_data(:parsed_dialog_tags)
  if dialog_options_hash.blank? && dialog_tags_hash.blank?
    log_and_update_message(:info, "Instantiating dialog_parser to populate dialog options")
    $evm.instantiate('/Service/Provisioning/StateMachines/Methods/DialogParser')
    dialog_options_hash = yaml_data(:parsed_dialog_options)
    dialog_tags_hash = yaml_data(:parsed_dialog_tags)
    dialog_parser_error if dialog_options_hash.blank? && dialog_tags_hash.blank?
  end

  log_and_update_message(:info, "dialog_options: #{dialog_options_hash.inspect}")
  log_and_update_message(:info, "tag_options: #{dialog_tags_hash.inspect}")
  return dialog_options_hash, dialog_tags_hash
end

def merge_service_item_dialog_values(build, dialogs_hash)
  merged_hash = Hash.new { |h, k| h[k] = {} }
  if dialogs_hash[0].nil?
    merged_hash = dialogs_hash[build] || {}
  else
    merged_hash = dialogs_hash[0].merge(dialogs_hash[build] || {})
  end
  merged_hash
end

def merge_dialog_information(build, dialog_options_hash, dialog_tags_hash)
  merged_options_hash = merge_service_item_dialog_values(build, dialog_options_hash)
  merged_tags_hash = merge_service_item_dialog_values(build, dialog_tags_hash)
  log_and_update_message(:info, "build: #{build} merged_options_hash: #{merged_options_hash.inspect}")
  log_and_update_message(:info, "build: #{build} merged_tags_hash: #{merged_tags_hash.inspect}")
  return merged_options_hash, merged_tags_hash
end

def get_array_of_builds(dialogs_options_hash)
  builds = []
  dialogs_options_hash.each do |build, options|
    next if build.zero?
    builds << build
  end
  builds.sort
end

def get_requester(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing get_requester...", true)
  @user = $evm.vmdb('user').find_by_id(merged_options_hash[:evm_owner_id]) ||
    $evm.vmdb('user').find_by_userid(merged_options_hash[:userid]) ||
    $evm.root['user']
  merged_options_hash[:user_name]        = /^[^@]*/.match(@user.userid).to_s
  merged_options_hash[:owner_first_name] = @user.first_name ? @user.first_name : 'Cloud'
  merged_options_hash[:owner_last_name]  = @user.last_name ? @user.last_name : 'Admin'
  merged_options_hash[:owner_email]      = @user.email ? @user.email : $evm.object['to_email_address']
  log_and_update_message(:info, "Build: #{build} - User: #{@user.userid} id: #{@user.id} email: #{@user.email}")

  # Stuff the current group information
  merged_options_hash[:group_id] = @user.current_group.id
  merged_options_hash[:group_name] = @user.current_group.description
  log_and_update_message(:info, "Build: #{build} - Group: #{merged_options_hash[:group_name]} " \
                         "id: #{merged_options_hash[:group_id]}")
  log_and_update_message(:info, "Processing get_requester...Complete", true)
end

def get_tenant(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing get_tenant...", true)
  tenant_category = :tenant
  tenant_name = @user.current_group.tags(tenant_category).first rescue nil

  unless tenant_name.nil?
    merged_tags_hash[tenant_category] = tenant_name
    @service.tag_assign("#{tenant_category.to_s}/#{tenant_name}")
    log_and_update_message(:info, "Build: #{build} - Tenant: #{tenant_name}")
  end
  log_and_update_message(:info, "Processing get_tenant...Complete", true)
end

def get_template(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing get_template...", true)
  template_search_by_criteria = merged_options_hash[:guid] ||
    merged_options_hash[:template] ||
    merged_options_hash[:name]

  @template = $evm.vmdb(:template_vmware).find_by_guid(template_search_by_criteria) ||
    $evm.vmdb(:template_vmware).find_by_id(template_search_by_criteria) ||
    $evm.vmdb(:template_vmware).find_by_name(template_search_by_criteria)
  raise "No template found" if @template.blank?

  log_and_update_message(:info, "Build: #{build} - template: #{@template.name} guid: #{@template.guid} " \
                         "on provider: #{@template.ext_management_system.name}")
  merged_options_hash[:name] = @template.name
  merged_options_hash[:guid] = @template.guid
  log_and_update_message(:info, "Processing get_template...Complete", true)
end

def get_provision_type(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing get_provision_type...", true)
  # Valid types for vmware:  vmware, pxe, netapp_rcu
  if merged_options_hash[:provision_type].blank?
    merged_options_hash[:provision_type] = 'vmware'
  end
  log_and_update_message(:info, "Build: #{build} - provision_type: #{merged_options_hash[:provision_type]}")
  log_and_update_message(:info, "Processing get_provision_type...Complete", true)
end

def get_vm_name(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing get_vm_name", true)
  new_vm_name = merged_options_hash[:vm_name] || merged_options_hash[:vm_target_name]
  if new_vm_name.blank?
    merged_options_hash[:vm_name] = 'changeme'
  else
    unless $evm.vmdb(:vm_or_template).find_by_name(merged_options_hash[:vm_name]).blank?
      # Loop through 0-999 and look to see if the vm_name already exists in the vmdb to avoid collisions
      for i in (1..999)
        proposed_vm_name = "#{merged_options_hash[:vm_name]}#{i}"
        log_and_update_message(:info, "Checking for existence of vm: #{proposed_vm_name}")
        break if $evm.vmdb(:vm_or_template).find_by_name(proposed_vm_name).blank?
      end
      merged_options_hash[:vm_name] = proposed_vm_name
    end
  end
  log_and_update_message(:info, "Build: #{build} - VM Name: #{merged_options_hash[:vm_name]}")
  log_and_update_message(:info, "Processing get_vm_name...Complete", true)
end

def get_network(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing get_network...", true)
  if merged_options_hash[:vlan].blank?
    case merged_tags_hash[:environment]
    when 'dev', 'test';
      # if dev/test
      #merged_options_hash[:vlan] = 'VM Network'
    when 'stage', 'prod';
      # if stage/prod
      #merged_options_hash[:vlan] = 'dvs_General - 10.1.45.0/24'
    else
      # Set a default vlan here
      #merged_options_hash[:vlan] = 'VM Network'
    end
    log_and_update_message(:info, "Build: #{build} - vlan: #{merged_options_hash[:vlan]}")
  end
  log_and_update_message(:info, "Processing get_network...Complete", true)
end

def get_flavor(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing get_flavor...", true)
  flavor = merged_options_hash[:flavor] ||
    merged_options_hash[:instance_type] ||
    merged_options_hash[:sizing] rescue nil
  return if flavor.blank?

  case flavor
  when 'xsmall';    merged_options_hash[:cores_per_socket], merged_options_hash[:vm_memory] = '1', '512'
  when 'small';     merged_options_hash[:cores_per_socket], merged_options_hash[:vm_memory] ='1', '1024'
  when 'medium';    merged_options_hash[:cores_per_socket], merged_options_hash[:vm_memory] = '2', '2048'
  when 'large';     merged_options_hash[:cores_per_socket], merged_options_hash[:vm_memory] = '2', '4096'
  when 'xlarge';    merged_options_hash[:cores_per_socket], merged_options_hash[:vm_memory] = '4', '4096'
  when 'xxlarge';   merged_options_hash[:cores_per_socket], merged_options_hash[:vm_memory] = '4', '6144'
  when 'xxxlarge';  merged_options_hash[:cores_per_socket], merged_options_hash[:vm_memory] = '8', '8192'
  else
    # merged_options_hash[:cores_per_socket], merged_options_hash[:vm_memory] = '1', '1024'
  end
  merged_tags_hash[:flavor] = flavor if flavor
  log_and_update_message(:info, "Build: #{build} - flavor: #{flavor} cores_per_socket: #{merged_options_hash[:cores_per_socket]} " \
                         "vm_memory: #{merged_options_hash[:vm_memory]}")
  log_and_update_message(:info, "Processing get_flavor...Complete", true)
end

# use this to set retirement
def get_retirement(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing get_retirement...", true)
  case merged_tags_hash[:environment]
  when 'dev';       merged_options_hash[:retirement], merged_options_hash[:retirement_warn] = 1.week.to_i, 3.days.to_i
  when 'test';      merged_options_hash[:retirement], merged_options_hash[:retirement_warn] = 2.days.to_i, 1.day.to_i
  when 'prod';      merged_options_hash[:retirement], merged_options_hash[:retirement_warn] = 1.month.to_i, 1.week.to_i
  else
    # Set a default retirement here
    #merged_options_hash[:retirement], merged_options_hash[:retirement_warn] = 1.month.to_i, 1.week.to_i
  end
  log_and_update_message(:info, "Build: #{build} - retirement: #{merged_options_hash[:retirement]}" \
                         "retirement_warn: #{merged_options_hash[:retirement_warn]}")
  log_and_update_message(:info, "Processing get_retirement...Complete", true)
end

def get_extra_options(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing get_extra_options...", true)
  # stuff the service guid & id so that the VMs can be added to the service later
  merged_options_hash[:service_id] = @service.id unless @service.nil?
  merged_options_hash[:service_guid] = @service.guid unless @service.nil?
  log_and_update_message(:info, "Build: #{build} - service_id: #{merged_options_hash[:service_id]}" \
                         "service_guid: #{merged_options_hash[:service_guid]}")
  log_and_update_message(:info, "Processing get_extra_options...Complete", true)
end


def process_builds(dialog_options_hash, dialog_tags_hash)
  builds = get_array_of_builds(dialog_options_hash)
  log_and_update_message(:info, "builds: #{builds.inspect}")
  builds.each do |build|
    merged_options_hash, merged_tags_hash = merge_dialog_information(build, dialog_options_hash, dialog_tags_hash)

    # get requester and tenant information
    get_requester(build, merged_options_hash, merged_tags_hash)

    # get the tenant
    get_tenant(build, merged_options_hash, merged_tags_hash)

    # get template
    get_template(build, merged_options_hash, merged_tags_hash)

    # set the provision type (vmware, pxe, iso, native_clone)
    get_provision_type(build, merged_options_hash, merged_tags_hash)

    # get vm_name
    get_vm_name(build, merged_options_hash, merged_tags_hash)

    # get networking, security groups, keypairs
    get_network(build, merged_options_hash, merged_tags_hash)

    # get vCPU/vRAM/flavor based on flavor parameter
    get_flavor(build, merged_options_hash, merged_tags_hash)

    # get retirement
    get_retirement(build, merged_options_hash, merged_tags_hash)

    # hard-code/override any options/tags
    get_extra_options(build, merged_options_hash, merged_tags_hash)

    # create all specified categories/tags again just to be sure we got them all
    merged_tags_hash.each do |key, value|
      log_and_update_message(:info, "Processing tag: #{key.inspect} value: #{value.inspect}")
      tag_category = key.downcase
      Array.wrap(value).each do |tag_entry|
        process_tag(tag_category, tag_entry.downcase)
      end
    end
    # log each builds tags and options
    merged_tags_hash.each {|k,v| log_and_update_message(:info, "Build: #{build} - merged_tags_hash: {#{k.inspect}=>#{v.inspect}}") }
    merged_options_hash.each {|k,v| log_and_update_message(:info, "Build: #{build} - merged_options_hash: {#{k.inspect}=>#{v.inspect}}") }

    # call build_provision_request using merged_options_hash and merged_tags_hash
    request = build_provision_request(build, merged_options_hash, merged_tags_hash)
    log_and_update_message(:info, "Build: #{build} - VM Provision request #{request.id} for #{merged_options_hash[:vm_name]} " \
                           "successfully submitted", true)
  end
end

def set_valid_provisioning_args
  # set required VMware provisioning dialog fields everything else will get stuffed into :ws_values
  valid_templateFields    = [:name, :request_type, :guid, :cluster]
  valid_vmFields          = [:vm_name, :number_of_sockets, :cores_per_socket, :vm_memory, :number_of_vms, :provision_type]
  valid_vmFields         += [:vlan, :retirement, :retirement_warn, :placement_auto, :vm_description, :vm_auto_start]
  valid_vmFields         += [:linked_clone, :vm_prefix, :network_adapters, :placement_cluster_name]
  valid_requester_args    = [:user_name, :owner_first_name, :owner_last_name, :owner_email, :auto_approve]
  return valid_templateFields, valid_vmFields, valid_requester_args
end

def build_provision_request(build, merged_options_hash, merged_tags_hash)
  log_and_update_message(:info, "Processing build_provision_request...", true)
  valid_templateFields, valid_vmFields, valid_requester_args = set_valid_provisioning_args

  # arg1 = version
  args = ['1.1']

  # arg2 = templateFields
  template_args = merged_options_hash.select { |k, v| valid_templateFields.include? k }.to_a.collect { |v| v.join('=') }.join('|')
  valid_templateFields.each { |k| merged_options_hash.delete(k) }
  args << template_args

  # arg3 = vmFields
  vm_args = merged_options_hash.select { |k, v| valid_vmFields.include? k }.to_a.collect { |v| v.join('=') }.join('|')
  valid_vmFields.each { |k| merged_options_hash.delete(k) }
  args << vm_args

  # arg4 = requester
  requester_args = merged_options_hash.select { |k, v| valid_requester_args.include? k }.to_a.collect { |v| v.join('=') }.join('|')
  valid_requester_args.each { |k| merged_options_hash.delete(k) }
  args << requester_args

  # arg5 = tags
  args << merged_tags_hash.collect { |k, v| "#{k.to_s}=#{v}" }.join('|')

  # arg6 = Web Service Values (ws_values)
  # put all remaining merged_options_hash and merged_tags_hash in ws_values hash for later use in the state machine
  args << merged_options_hash.merge(merged_tags_hash).collect { |k, v| "#{k.to_s}=#{v}" }.join('|')

  # arg7 = emsCustomAttributes
  args << nil

  # arg8 = miqCustomAttributes
  args << nil

  log_and_update_message(:info, "Build: #{build} - Building provision request with the following arguments: #{args.inspect}")
  request = $evm.execute('create_provision_request', *args)

  # Reset the @template for the next build
  @template, @user = nil, nil
  log_and_update_message(:info, "Processing build_provision_request...Complete", true)
  return request
end

begin
  @task = $evm.root['service_template_provision_task']

  @service = @task.destination
  log_and_update_message(:info, "Service: #{@service.name} id: #{@service.id} tasks: #{@task.miq_request_tasks.count}")

  dialog_options_hash, dialog_tags_hash = parsed_dialog_information

  # :dialog_service_name
  override_service_attribute(dialog_options_hash.fetch(0, {}), "name")

  # :dialog_service_description
  override_service_attribute(dialog_options_hash.fetch(0, {}), "description")

  # :dialog_service_retires_on
  override_service_attribute(dialog_options_hash.fetch(0, {}), "retires_on")

  # :dialog_service_retirement_warn
  override_service_attribute(dialog_options_hash.fetch(0, {}), "retirement_warn")

  # tag service with all dialog_tag_0_ parameters
  tag_service(dialog_tags_hash)

  # prepare the builds and execute them
  process_builds(dialog_options_hash, dialog_tags_hash)

rescue => err
  log_and_update_message(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  @task.finished("#{err}") if @task
  exit MIQ_ABORT
end
