# amazon_build_vmprovision_request.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: Simple method to kick off an provisioning request from the following:
#  a) Generic Service Catalog Item that provisions one or many VMs into a service
#  b) Service Button for the purpose of adding VMs to an existing service
#  c) API driven for the purpose of adding VMs to an existing service or just provisioning new VMs without a service
#  d) VM driven from a button, Policy or Alert event for Flexing
#
# Inputs: dialog_option_[0-9]_template, dialog_option_[0-9]_flavor, dialog_tag_[0-9]_environment, etc...
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level,"#{msg}")
    @task.message = msg if @task && update_message
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  # Look for service dialog variables in the dialog options hash that start with "dialog_tag_[0-9]" and "dialog_option_[0-9]"
  def get_dialog_hashes(dialog_options)
    log(:info, "Processing get_dialog_tags_hash...", true)
    dialogs_tags_hash, dialogs_options_hash = {}, {}
    dialog_tags_regex = /^dialog_tag_(\d*)_(.*)/
    dialog_options_regex = /^dialog_option_(\d*)_(.*)/
    # Loop through all of the tags and build a dialogs_tags_hash
    dialog_options.each do |k, v|
      next if v.blank?
      if dialog_tags_regex =~ k
        build = $1.to_i
        tag_category = $2.to_sym
        tag_value = v.downcase
        log(:info, "Build: #{build} - Adding tag: {#{tag_category.inspect} => #{tag_value.inspect}} to dialogs_tags_hash)")
        (dialogs_tags_hash[build] ||={})[tag_category] = tag_value
      elsif dialog_options_regex =~ k
        build = $1.to_i
        option_key = $2.to_sym
        option_value = v
      else
        build = 0
        option_key = k.to_sym
        option_value = v
      end
      next if option_key.blank?
      log(:info, "Build: #{build} - Adding option: {#{option_key.inspect} => #{option_value.inspect}} to dialogs_options_hash)")
      (dialogs_options_hash[build]||={})[option_key] = option_value
    end
    log(:info, "Inspecting dialogs_tags_hash: #{dialogs_tags_hash.inspect}")
    log(:info, "Inspecting dialogs_options_hash: #{dialogs_options_hash.inspect}")
    log(:info, "Processing get_dialog_tags_hash...Complete", true)
    return dialogs_tags_hash, dialogs_options_hash
  end

  # Loop through all tags from the dialog and create the categories and tags automatically
  def process_tags(category, single_value, tag)
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.to_s.downcase.gsub(/\W/,'_')
    tag_name = tag.to_s.downcase.gsub(/\W/, '_')

    # if the category exists else create it
    unless $evm.execute('category_exists?', category_name)
      log(:info, "Category #{category_name} doesn't exist, creating category")
      $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category}")
    end
    # if the tag exists else create it
    unless $evm.execute('tag_exists?', category_name, tag_name)
      log(:info, "Adding new tag #{tag_name} in Category #{category_name}")
      $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag}")
    end
  end

  # service_naming - name the service
  def service_naming(new_service_name=nil, new_service_description)
    log(:info, "Processing service_naming...", true)
    unless new_service_name.blank?
      log(:info, "Changing Service name: #{@service.name} to #{new_service_name}")
    else
      new_service_name = "#{@service.name}-#{Time.now.strftime('%Y%m%d-%H%M%S')}"
      log(:info, "Changing Service name: #{@service.name} to #{new_service_name}")
    end
    @service.name = new_service_name
    unless new_service_description.blank?
      log(:info, "Changing Service description from #{@service.description} to #{new_service_description}")
      @service.description = new_service_description
    end
    log(:info, "Processing service_naming...Complete", true)
  end

  # service_tagging - tag the parent service with tags
  def service_tagging(dialogs_tags_hash)
    log(:info, "Processing service_tagging...", true)
    unless dialogs_tags_hash[0].blank?
      dialogs_tags_hash[0].each do |k,v|
        log(:info, "Adding Tag: {#{k.inspect} => #{v.inspect}} to Service: #{@service.name}")
        process_tags( k, true, v )
        @service.tag_assign("#{k}/#{v}")
      end
    end
    log(:info, "Processing service_tagging...Complete", true)
  end

  # service_retirement - default the service retirement
  def service_retirement(dialog_options)
    log(:info, "Processing service_retirement...", true)
    service_retirement = dialog_options.fetch('dialog_service_retirement', 30)
    service_retirement_warning = dialog_options.fetch('dialog_service_retirement_warning', 7)
    new_service_retirement = (DateTime.now + service_retirement.to_i).strftime("%Y-%m-%d")
    log(:info, "Changing Service: #{@service.name} retires_on: #{new_service_retirement} retirement_warn: #{service_retirement_warning}")
    @service.retires_on = new_service_retirement.to_date
    @service.retirement_warn = service_retirement_warning.to_i
    log(:info, "Processing service_retirement...Complete", true)
  end

  # service_remove
  def service_remove()
    log(:info, "Processing service_remove...", true)
    # Get destination service object
    service = @task.destination if @task.respond_to?('destination')
    unless service.nil?
      log(:info, "Removing Service: #{service.name} Id: #{service.id} from CFME database")
      service.remove_from_vmdb
    end
    log(:info, "Processing service_remove...Complete", true)
  end

  # get requester and tenant information and allow a userid for provisioning on behalf of
  def get_requester(build, matching_options_hash, matching_tags_hash)
    log(:info, "Processing get_requester...", true)
    @user   = $evm.vmdb('user').find_by_id(matching_options_hash[:evm_owner_id]) || $evm.vmdb('user').find_by_userid(matching_options_hash[:userid])
    @user ||= $evm.vmdb('user').find_by_id($evm.root['user_id'])
    matching_options_hash[:user_name]        = /^[^@]*/.match(@user.userid).to_s
    matching_options_hash[:owner_first_name] = @user.first_name ? @user.first_name : 'Cloud'
    matching_options_hash[:owner_last_name]  = @user.last_name ? @user.last_name : 'Admin'
    matching_options_hash[:owner_email]      = @user.email ? @user.email : $evm.object['to_email_address']
    log(:info, "Build: #{build} - User: #{@user.userid} id: #{@user.id} email: #{@user.email}")
    # Stuff the current group information
    matching_options_hash[:group_id] = @user.current_group.id
    matching_options_hash[:group_name] = @user.current_group.description
    log(:info, "Build: #{build} - Group: #{@user.current_group.description} id: #{@user.current_group.id}")
    log(:info, "Processing get_requester...Complete", true)
  end

  def get_tenant(build, matching_options_hash, matching_tags_hash)
    log(:info, "Processing get_tenant...", true)
    tenant_category = $evm.object['tenant_category'] || 'tenant'
    tenant  = @user.current_group.tags(tenant_category).first rescue nil
    if tenant
      matching_tags_hash[tenant_category]     = tenant
      @service.tag_assign("#{tenant_category}/#{tenant}")
      log(:info, "Build: #{build} - Tenant: #{tenant}")
    end
    log(:info, "Processing get_tenant...Complete", true)
  end

  # get template based on incoming dialog_options
  def get_template(build, matching_options_hash, matching_tags_hash)
    log(:info, "Processing get_template...", true)
    template_search_by_criteria = matching_options_hash[:guid] || matching_options_hash[:template] || matching_options_hash[:name] || matching_options_hash[:os]
    @template = $evm.vmdb(:template_amazon).find_by_guid(template_search_by_criteria) || $evm.vmdb(:template_amazon).find_by_id(template_search_by_criteria)
    @template ||= $evm.vmdb(:template_amazon).find_by_name(template_search_by_criteria)

    unless @template
      # Search for templates tagged with 'prov_scope' => 'all' & product_name include option_?_os (I.e. 'windows', red hat') - then load balance them across different providers based on vm count
      log(:info, "Searching for templates tagged with 'prov_scope'=>'all' that inlcude product: #{template_search_by_criteria}")
      templates_array = $evm.vmdb(:template_amazon).all.select do |t|
        t.ext_management_system && t.tagged_with?('prov_scope', 'all') && t.operating_system[:product_name].downcase.include?(template_search_by_criteria) rescue next
      end.sort { |t1, t2| t1.ext_management_system.vms.count <=> t2.ext_management_system.vms.count }
      # get the first template in the list
      @template = templates_array.first unless templates_array.blank?
    end
    raise "No template found" if @template.blank?
    log(:info, "Build: #{build} - template: #{@template.name} product: #{@template.operating_system[:product_name].downcase rescue 'unknown'} guid: #{@template.guid} on provider: #{@template.ext_management_system.name}")
    matching_options_hash[:name] = @template.name
    matching_options_hash[:guid] = @template.guid
    log(:info, "Processing get_template...Complete", true)
  end

  # use this to name the vm or set it to changeme to run through the vm_name automate method
  def get_vm_name(build, matching_options_hash, matching_tags_hash)
    log(:info, "Processing get_vm_name", true)
    if matching_options_hash[:vm_name].blank?
      matching_options_hash[:vm_name] = 'changeme'
    else
      unless $evm.vmdb('vm_or_template').find_by_name(matching_options_hash[:vm_name]).blank?
        # Loop through 0-999 and look to see if the vm_name already exists in the vmdb to avoid collisions
        for i in (1..999)
          new_vm_name = "#{matching_options_hash[:vm_name]}#{i}"
          log(:info, "Checking for existence of vm: #{new_vm_name}")
          break if $evm.vmdb('vm_or_template').find_by_name(new_vm_name).blank?
        end
        matching_options_hash[:vm_name] = new_vm_name
      end
    end
    log(:info, "Build: #{build} - VM Name: #{matching_options_hash[:vm_name]}")
    log(:info, "Processing get_vm_name...Complete", true)
  end

  # get network, security_groups, key_pairs, etc...
  def get_network(build, matching_options_hash, matching_tags_hash)
    log(:info, "Processing get_network...", true)
    provider = @template.ext_management_system

    availability_zone_search = matching_options_hash[:placement_availability_zone] || matching_options_hash[:availability_zone]
    if availability_zone_search.blank?
      # availability_zone   = provider.availability_zones.first
    else
      availability_zone   = $evm.vmdb(:availability_zone).find_by_id(availability_zone_search) || provider.availability_zones.detect { |az| az.name == availability_zone_search }
    end
    matching_options_hash[:placement_availability_zone] = availability_zone.id unless availability_zone.blank?
    log(:info, "Build: #{build} - placement_availability_zone: #{matching_options_hash[:placement_availability_zone]}") unless availability_zone.blank?

    if matching_options_hash[:cloud_network].blank?
      # cloud_network = provider.cloud_networks.first
    else
      cloud_network   = $evm.vmdb(:cloud_network).find_by_id(matching_options_hash[:cloud_network]) || provider.cloud_networks.detect {|cn| cn.name == matching_options_hash[:cloud_network] }
    end
    matching_options_hash[:cloud_network] = cloud_network.id unless cloud_network.blank?
    log(:info, "Build: #{build} - cloud_network: #{matching_options_hash[:cloud_network]}") unless cloud_network.blank?

    if matching_options_hash[:security_groups].blank?
      security_group = provider.security_groups.first
    else
      security_group   = $evm.vmdb(:security_group).find_by_id(matching_options_hash[:security_groups]) || provider.security_groups.detect { |sg| sg.name == matching_options_hash[:security_groups] }
    end
    if security_group
      matching_options_hash[:security_groups] = security_group.id
      matching_options_hash[:security_groups_id] = security_group.id
      log(:info, "Build: #{build} - security_groups: #{matching_options_hash[:security_groups]}")
    end

    key_pair_search = matching_options_hash[:guest_access_key_pair] || matching_options_hash[:key_pair]
    if key_pair_search.blank?
      key_pair = provider.key_pairs.first
    else
      key_pair   = $evm.vmdb(:auth_key_pair_amazon).find_by_id(key_pair_search) || provider.key_pairs.detect {|kp| kp.name == key_pair_search }
    end
    if key_pair
      matching_options_hash[:guest_access_key_pair] = key_pair.id
      log(:info, "Build: #{build} - guest_access_key_pair: #{matching_options_hash[:guest_access_key_pair]}")
    end
    log(:info, "Processing get_network...Complete", true)
  end

  # get vCPU/vRAM/flavor based on flavor|sizing parameter
  def get_sizing(build, matching_options_hash, matching_tags_hash)
    log(:info, "Processing get_sizing...", true)
    flavor_sizing = matching_options_hash[:flavor] || matching_options_hash[:instance_type] || matching_options_hash[:sizing] rescue nil
    return if flavor_sizing.blank?
    provider = @template.ext_management_system
    flavor   = $evm.vmdb(:flavor_amazon).find_by_id(flavor_sizing) || provider.flavors.detect {|fl| fl.name == flavor_sizing }
    unless flavor.nil?
      log(:info, "flavor: #{flavor.name} id: #{flavor.id} cpus: #{flavor.cpus} memory: #{flavor.memory} ems_ref: #{flavor.ems_ref}")
      matching_options_hash[:instance_type] = flavor.id
      matching_tags_hash[:flavor] = flavor.name
      log(:info, "Build: #{build} - instance_type: #{matching_options_hash[:instance_type]}") unless matching_options_hash[:instance_type].blank?
    end
    log(:info, "Processing get_sizing...Complete", true)
  end

  # use this to set retirement
  def get_retirement(build, matching_options_hash, matching_tags_hash)
    log(:info, "Processing get_retirement...", true)
    case matching_tags_hash[:environment]
    when 'dev'
      # retire in one week (in seconds) and warn 3 days prior
      matching_options_hash[:retirement] = 1.week.to_i
      matching_options_hash[:retirement_warn] = 3.days.to_i
    when 'test'
      # retire in two days (in seconds) with no warning
      matching_options_hash[:retirement] = 2.days.to_i
    when 'prod'
      # retire in 4 weeks and warn 1 week
      matching_options_hash[:retirement] = 1.month.to_i
      matching_options_hash[:retirement_warn] = 1.week.to_i
    else
      # Set a default retirement here
      #matching_options_hash[:retirement] = 1.month.to_i
      #matching_options_hash[:retirement_warn] = 1.week.to_i
    end
    log(:info, "Build: #{build} - retirement: #{matching_options_hash[:retirement]}") unless matching_options_hash[:retirement].blank?
    log(:info, "Build: #{build} - retirement_warn: #{matching_options_hash[:retirement_warn]}") unless matching_options_hash[:retirement_warn].blank?
    log(:info, "Processing get_retirement...Complete", true)
  end

  # use this method to define extra provisioning options
  def get_extra_options(build, matching_options_hash, matching_tags_hash)
    log(:info, "Processing get_extra_options...", true)

    # stuff the service guid & id so that the VMs can be added to the service later
    matching_options_hash[:service_id] = @service.id unless @service.nil?
    matching_options_hash[:service_guid] = @service.guid unless @service.nil?
    log(:info, "Build: #{build} - service_id: #{matching_options_hash[:service_id]}") unless matching_options_hash[:service_id].blank?
    log(:info, "Build: #{build} - service_guid: #{matching_options_hash[:service_guid]}") unless matching_options_hash[:service_guid].blank?
    log(:info, "Processing get_extra_options...Complete", true)
  end

  # set_valid_provisioning_args
  def set_valid_provisioning_args()
    valid_templateFields = [:name, :request_type, :guid, :cluster]
    @valid_provisioning_templateFields = valid_templateFields

    valid_vmFields  = [:vm_name, :number_of_vms, :vlan, :retirement, :retirement_warn]
    valid_vmFields += [:vm_prefix, :network_adapters, :placement_auto, :vm_description, :vm_auto_start, :placement_cluster_name]
    valid_vmFields += [:floating_ip_address, :placement_availability_zone, :guest_access_key_pair, :security_groups, :cloud_network, :cloud_subnet, :instance_type]
    valid_vmFields += [:cloud_tenant]
    @valid_provisioning_vmFields = valid_vmFields

    valid_requester_args = [:user_name, :owner_first_name, :owner_last_name, :owner_email, :auto_approve]
    @valid_provisioning_requester = valid_requester_args
  end

  # Populate arguments and submit provision request using incoming tags_hash and options_hash
  def build_provision_request(build, tags_hash, options_hash)
    log(:info, "Processing build_provision_request...", true)

    # arg1 = version
    args = ['1.1']

    # arg2 = templateFields
    template_args = options_hash.select { |k, v| @valid_provisioning_templateFields.include? k }.to_a.collect { |v| v.join('=') }.join('|')
    #Remove any hash keys there were used in the template_args
    @valid_provisioning_templateFields.each { |k| options_hash.delete(k) }
    args << template_args

    # arg3 = vmFields
    vm_args = options_hash.select { |k, v| @valid_provisioning_vmFields.include? k }.to_a.collect { |v| v.join('=') }.join('|')
    #Remove any hash keys there were used in the vm_args
    @valid_provisioning_vmFields.each { |k| options_hash.delete(k) }
    args << vm_args

    # arg4 = requester
    requester_args = options_hash.select { |k, v| @valid_provisioning_requester.include? k }.to_a.collect { |v| v.join('=') }.join('|')
    #Remove any hash keys there were used in the vm_args
    @valid_provisioning_requester.each { |k| options_hash.delete(k) }
    args << requester_args

    # arg5 = tags
    args << tags_hash.collect { |k, v| "#{k.to_s}=#{v}" }.join('|')

    # arg6 = Web Service Values (ws_values)
    # put all remaining options_hash and tags_hash in the ws_values hash for later use in the state machine
    args << options_hash.merge(tags_hash).collect { |k, v| "#{k.to_s}=#{v}" }.join('|')

    # arg7 = emsCustomAttributes
    args << nil

    # arg8 = miqCustomAttributes
    args << nil

    log(:info, "Build: #{build} - Building provision request with the following arguments: #{args.inspect}")
    request_id = $evm.execute('create_provision_request', *args)
    log(:info, "Build: #{build} - Processing build_provision_request...Complete", true)
    # Reset variables for the next build
    @template, @user, @tenant = nil
    log(:info, "Processing build_provision_request...Complete", true)
    return request_id
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  set_valid_provisioning_args()

  case $evm.root['vmdb_object_type']

  when 'service_template_provision_task'
    @task = $evm.root['service_template_provision_task']
    # Executed via generic service catalog item
    @service = @task.destination

    # build a hash of dialog_options
    dialog_options = @task.dialog_options
    dialogs_tags_hash, dialogs_options_hash = get_dialog_hashes(dialog_options)

    # Service naming
    service_naming(dialog_options.fetch('dialog_service_name', nil), dialog_options.fetch('dialog_service_description', nil))
    # Service tagging
    service_tagging(dialogs_tags_hash)
    # Service retirement
    service_retirement(dialog_options)
  when 'service'
    # Executed via button from a service to provision a new VM into a Service
    @service = $evm.root['service']
    # build a hash of dialog_options
    dialog_options = Hash[$evm.root.attributes.sort.collect { |k, v| [k, v] if k.starts_with?('dialog_') }]
    dialogs_tags_hash, dialogs_options_hash = get_dialog_hashes(dialog_options)
  when 'automation_task'
    # Executed via a API call
    @task = $evm.root['automation_task']
    log(:info, "Automtaion Task: #{@task.id} Automation Request: #{@task.automation_request.id}")

    service_search_method = $evm.root['service_guid'] || $evm.root['service_id'] rescue nil
    log(:info, "service_search_method: #{service_search_method}")
    @service = $evm.vmdb('service').find_by_guid(service_search_method) || $evm.vmdb('service').find_by_id(service_search_method) unless service_search_method.nil?
    log(:info, "service: #{@service.inspect}")
    # build a hash of dialog_options
    dialog_options = Hash[$evm.root.attributes.sort.collect { |k, v| [k, v] if k.starts_with?('dialog_') }]
    dialogs_tags_hash, dialogs_options_hash = get_dialog_hashes(dialog_options)
  when 'vm'
    # Executed via a button, policy or an Alert on a Flexed VM
    vm = $evm.root['vm']

    # Get service from vm
    @service = vm.service rescue nil
    raise "vm.service not found" if @service.nil?

    # Get miq_provision from vm
    prov = vm.miq_provision
    raise "$evm.root['vm'].miq_provision object not found." if prov.nil?

    # log the tags from the vm
    log(:info, "VM: #{vm.name} tags: #{vm.tags.inspect}")

    # Get the VMs flex_monitor tag
    flex_monitor = vm.tags(:flex_monitor).first rescue false

    # Skip processing if vm is not tagged with flex_monitor = true
    raise  "VM: #{vm.name} tag: {:flex_monitor => #{flex_monitor}}" unless flex_monitor =~ (/(true|t|yes|y|1)$/i)

    # Get the flex_maximum tag else set it to zero
    flex_maximum = vm.tags(:flex_maximum).first.to_i
    # Get the flex_current tag else set it to zero
    flex_current = vm.tags(:flex_current).first.to_i
    # Get the flex_pending tag else set it to zero
    flex_pending = vm.tags(:flex_pending).first.to_i

    if $evm.root['object_name'] == 'Event'
      # object_name = 'Event' means that we were triggered from an Alert
      log(:info, "Detected Alert driven event - $evm.root['miq_alert_description']: #{$evm.root['miq_alert_description'].inspect}")
      (flex_options_hash||={})[:flex_reason] = $evm.root['miq_alert_description']
    elsif $evm.root['ems_event']
      # ems_event means that were triggered via Control Policy
      log(:info, "Detected Policy driven event - $evm.root['ems_event']: #{$evm.root['ems_event'].inspect}")
      (flex_options_hash||={})[:flex_reason] = $evm.root['ems_event'].event_type
    else
      unless $evm.root['dialog_miq_alert_description'].nil?
        log(:info, "Detected Service dialog driven event")
        # If manual creation add dialog input notes to flex_options_hash
        (flex_options_hash||={})[:flex_reason] = "VM flexed manually - #{$evm.root['dialog_miq_alert_description']}"
      else
        log(:info, "Detected manual driven event")
        # If manual creation add default notes to flex_options_hash
        (flex_options_hash||={})[:flex_reason] = "VM flexed manually"
      end
    end

    # Create flex_pending tags if they do not already exist
    process_tags('flex_pending', true, flex_pending)

    # if flex_current + flex_pending is less than flex_maximum
    if flex_current + flex_pending < flex_maximum
      # Increment flex_pending by 1
      new_flex_pending = flex_pending + 1
      # Create flex_pending tags if they do not already exist
      process_tags('flex_pending', true, new_flex_pending)
      # Inherit all of the VMs provisioning templateFields
      @valid_provisioning_templateFields.each { |key| flex_options_hash[key] = prov.get_option(key)}
      # Inherit all of the VMs provisioning vmFields
      @valid_provisioning_vmFields.each { |key| flex_options_hash[key] = prov.get_option(key) unless prov.get_option(key).blank?}
      # Inherit all of the VMs provisioning requester information
      @valid_provisioning_requester.each { |key| flex_options_hash[key] = prov.get_option(key)}

      flex_tags_hash = {}
      # Inherit all of the source VM tags
      vm.tags.each do |cat_tagname|
        category, tag_value = cat_tagname.split('/')
        next if category.include?('flex') || category.include?('folder_path')
        log(:info, "Adding category: {#{category} => #{tag_value}} to flex_tags_hash")
        flex_tags_hash["#{category}"] = tag_value
      end

      # Override provisioning options here
      flex_options_hash[:service_id]        = @service.id
      flex_options_hash[:number_of_vms]     = 1
      flex_options_hash[:user_name]         = prov.userid
      flex_options_hash[:requester_id]      = prov.requester_id
      flex_options_hash[:evm_owner_id]      = vm.evm_owner_id
      flex_options_hash[:flex_vm_guid]      = vm.guid
      flex_options_hash[:flex_vm_name]      = vm.name
      flex_options_hash[:guid]              = prov.vm_template.guid
      flex_options_hash[:name]              = prov.vm_template.name

      # Tag service with :flex_pending => new_flex_pending
      unless vm.tagged_with?('flex_pending', new_flex_pending)
        log(:info, "Assigning tag: {:flex_pending => #{new_flex_pending}} to VM: #{vm.name}")
        vm.tag_assign("flex_pending/#{new_flex_pending}")
      end

      # Convert flex_tags_hash keys to symbols
      (dialogs_tags_hash||={})[1] = Hash[flex_tags_hash.map{ |k, v| [k.to_sym, v] }]
      log(:info, "Inspecting dialogs_tags_hash: #{dialogs_tags_hash.inspect}")
      # Convert flex_options_hash keys to symbols
      (dialogs_options_hash||={})[1] = Hash[flex_options_hash.map{ |k, v| [k.to_sym, v] }]
      log(:info, "Inspecting dialogs_options_hash: #{dialogs_options_hash.inspect}")
    else
      raise "VM: #{vm.name} flex_maximum: #{flex_maximum} has been reached"
    end
  else
    raise "Invalid $evm.root['vmdb_object_type']: #{$evm.root['vmdb_object_type']}"
  end # case $evm.root['vmdb_object_type']

  log(:info, "Detected Service: #{@service.name} id: #{@service.id} guid: #{@service.guid}") unless @service.nil?

  # create an array of builds
  builds = {}
  dialogs_options_hash.each do |build, options|
    unless build.to_i.zero?
      sequence = options["dialog_option_#{build}_build_sequence"]
      (builds[sequence] ||= []) << build
    end
  end

  # looping through all build sequences
  build_sequences = builds.keys.sort
  build_sequences.each do |sequence|
    matching_builds = builds[sequence]

    # concurrently build all builds in 'matching_builds'
    matching_builds.each do |build|
      # merge dialog_option_0 stuff with current build
      unless dialogs_options_hash[0].nil?
        matching_options_hash = dialogs_options_hash[0].merge(dialogs_options_hash[build] || {})
      else
        matching_options_hash = dialogs_options_hash[build] || {}
      end

      # merge dialog_tag_0 stuff with current build
      unless dialogs_tags_hash[0].nil?
        matching_tags_hash = dialogs_tags_hash[0].merge(dialogs_tags_hash[build] || {})
      else
        matching_tags_hash = dialogs_tags_hash[build] || {}
      end

      # get requester and tenant information
      get_requester(build, matching_options_hash, matching_tags_hash)

      # get tenant
      get_tenant(build, matching_options_hash, matching_tags_hash)

      # get template
      get_template(build, matching_options_hash, matching_tags_hash)

      # get vm_name
      get_vm_name(build, matching_options_hash, matching_tags_hash)

      # get networking, security groups, keypairs
      get_network(build, matching_options_hash, matching_tags_hash)

      # get vCPU/vRAM/flavor based on sizing parameter
      get_sizing(build, matching_options_hash, matching_tags_hash)

      # get retirement
      get_retirement(build, matching_options_hash, matching_tags_hash)

      # hard code/override any options/tags
      get_extra_options(build, matching_options_hash, matching_tags_hash)

      # dynamically create all specified categories/tags
      matching_tags_hash.each { |category, tag| process_tags( category, true, tag ) }

      # log each builds tags and options
      matching_tags_hash.each {|k,v| log(:info, "Build: #{build} - matching_tags_hash: #{k.inspect}=>#{v.inspect}") }
      matching_options_hash.each {|k,v| log(:info, "Build: #{build} - matching_options_hash: #{k.inspect}=>#{v.inspect}") }

      # call build_provision_request using matching_options_hash and matching_tags_hash
      request_id = build_provision_request(build, matching_tags_hash, matching_options_hash)
      log(:info, "Build: #{build} - VM Provision request #{request_id.id} for #{matching_options_hash[:vm_name]} successfully submitted", true)
    end # matching_builds.each do
  end # build_sequences.each do

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  @task.finished("#{err}") if @task
  service_remove() if @task
  exit MIQ_ABORT
end
