# CatalogBundleInitialization.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Notes: This method Performs the following functions:
# 1. Look for all Service Dialog Options in the $evm.root['service_template_provision_task'].dialog_options
# 2. Set the name of the service
# 3. Set tags on the service
# 4. Set retirement on the service
# 5. Pass down any dialog options and tags to child catalog items pointing to CatalogItemInitialization
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
    @task.message = msg if @task && update_message
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  # get_options_hash
  def get_dialog_options_hash(dialog_options)
    log(:info, "Processing get_dialog_options_hash...", true)
    # Setup regular expression for service dialog tags
    options_regex = /^(dialog_option|dialog_tag)_(\d*)_(.*)/i
    dialogs_options_hash = {}

    # Loop through all of the options and build an dialogs_options_hash from them
    dialog_options.each do |k,v|
      option_key = k.downcase.to_sym
      if options_regex =~ k
        sequence_id = $2.to_i

        unless v.blank?
          log(:info, "Adding sequence_id: {#{sequence_id} => {#{option_key.inspect} => #{v.inspect}} to dialogs_options_hash")
          if dialogs_options_hash.has_key?(sequence_id)
            dialogs_options_hash[sequence_id][option_key] = v
          else
            dialogs_options_hash[sequence_id] = { option_key => v }
          end
        end
      else
        # If options_regex does not match then stuff dialog options into dialogs_options_hash[0]
        sequence_id = 0
        unless v.nil?
          log(:info, "Adding sequence_id: {#{sequence_id} => {#{option_key.inspect} => #{v.inspect}} to dialogs_options_hash")
          if dialogs_options_hash.has_key?(sequence_id)
            dialogs_options_hash[sequence_id][option_key] = v
          else
            dialogs_options_hash[sequence_id] = { option_key => v }
          end
        end
      end # if options_regex =~ k
    end # dialog_options.each do
    log(:info, "Inspecting dialogs_options_hash:<#{dialogs_options_hash.inspect}>")
    log(:info, "Processing get_dialog_options_hash...Complete", true)
    return dialogs_options_hash
  end

  # Loop through all tags from the dialog and create the categories and tags automatically
  def process_tags(category, single_value, tag)
    log(:info, "Processing process_tags...", true)
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.to_s.downcase.gsub(/\W/,'_')
    tag_name = tag.to_s.downcase.gsub(/\W/,'_')

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
    log(:info, "Processing process_tags...Complete", true)
  end

  # service_naming - name the service
  def service_naming(dialogs_options_hash)
    log(:info, "Processing service_naming...", true)
    new_service_name = dialogs_options_hash[0][:dialog_service_name] rescue nil
    new_service_description = dialogs_options_hash[0][:dialog_service_description] rescue nil

    if new_service_name.blank?
      new_service_name = "#{@service.name}-#{Time.now.strftime('%Y%m%d-%H%M%S')}"
    end
    log(:info, "Service name: #{new_service_name}")
    @service.name = new_service_name

    unless new_service_description.blank?
      log(:info, "Service description #{new_service_description}")
      @service.description = new_service_description
    end
    log(:info, "Processing service_naming...Complete", true)
  end

  # service_tagging - tag the service with tags in dialogs_options_hash[0]
  def service_tagging(dialogs_options_hash)
    log(:info, "Processing service_tagging...", true)
    # Setup regular expression for service dialog tags
    tags_regex = /^dialog_tag_0_(.*)/i
    # Look for tags with a sequence_id of 0 to tag the service
    dialogs_options_hash[0].each do |k, v|
      log(:info, "Processing Tag Key:<#{k.inspect}> Value:<#{v.inspect}>")
      next if v.blank?
      if tags_regex =~ k
        tag_category = $1.downcase
        tag_value = v.downcase
        process_tags( tag_category, true, tag_value )
        log(:info, "Adding Tag: {#{k.inspect} => #{v.inspect}} to Service:<#{@service.name}>")
        @service.tag_assign("#{tag_category}/#{tag_value}")
      end # if tags_regex
    end # dialogs_options_hash[0].each
  end

  # service_retirement - default the service retirement
  def service_retirement(dialogs_options_hash)
    log(:info, "Processing service_retirement...", true)
    new_service_retirement = dialogs_options_hash[0][:dialog_service_retirement] rescue nil
    new_service_retirement_warning = dialogs_options_hash[0][:dialog_service_retirement_warning] rescue nil
    if new_service_retirement.nil?
      # service retirement based tag
      service_retirement_tag = dialogs_options_hash[0][:dialog_tag_0_environment] rescue nil
      case service_retirement_tag
      when 'dev'
        # retire service in 2 weeks with 3 day warning
        new_service_retirement = 14
        new_service_retirement_warning = 3
      when 'test'
        # retire service in 1 week with 1 day warning
        new_service_retirement = 7
        new_service_retirement_warning = 1
      when 'prod'
        # retire service in 1 month with 1 week warning
        new_service_retirement = 30
        new_service_retirement_warning = 7
      else
        new_service_retirement = nil
        new_service_retirement_warning = nil
      end
    end
    unless new_service_retirement.nil?
      new_service_retirement = (DateTime.now + new_service_retirement.to_i).strftime("%Y-%m-%d")
      @service.retires_on = new_service_retirement.to_date
      @service.retirement_warn = new_service_retirement_warning.to_i unless new_service_retirement_warning.nil?
    end
    log(:info, "Service: #{@service.name} retires_on: #{@service.retires_on} retirement_warn: #{@service.retirement_warn}")
    log(:info, "Processing service_retirement...Complete", true)
  end

  # look up the tenant if any and set the tags on the service and in prov
  def service_tenant(dialogs_options_hash)
    log(:info, "Processing service_tenant...", true)
    tenant_category       = $evm.object['tenant_category'] || 'tenant'
    cloud_tenant_search   = @user.current_group.tags(tenant_category).first rescue nil
    @tenant               = $evm.vmdb(:cloud_tenant).find_by_name(cloud_tenant_search)
    if @tenant
      log(:info, "Tenant: #{@tenant.name}")
      dialogs_options_hash[0]["dialog_tag_0_#{tenant_category}".to_sym] = @tenant.name
    end
    log(:info, "Processing service_tenant...Complete", true)
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  @task = $evm.root['service_template_provision_task']
  @user = $evm.vmdb('user').find_by_id($evm.root['user_id'])

  # build a hash of dialog_options
  dialog_options = @task.dialog_options

  # Get destination service object
  @service = @task.destination
  log(:info, "Detected Service:<#{@service.name}> Id:<#{@service.id}> Tasks:<#{@task.miq_request_tasks.count}>")

  # Get dialog options from task
  dialog_options = @task.dialog_options
  log(:info, "dialog_options: #{dialog_options.inspect}")

  # Build dialogs_options_hash
  dialogs_options_hash = get_dialog_options_hash(dialog_options)

  # Service naming
  service_naming(dialogs_options_hash)

  # Service Tenant Search
  service_tenant(dialogs_options_hash)

  # Tag Service
  service_tagging(dialogs_options_hash)

  # Set Service Retirement
  service_retirement(dialogs_options_hash)

  # Process Child Services
  @task.miq_request_tasks.each do |t|
    # Child Service
    child_service = t.destination
    # Service Bundle Resource
    child_service_resource = t.service_resource

    # Increment the provision_index number since the child resource starts with a zero
    provision_index = child_service_resource.provision_index + 1
    log(:info, "Child service name: #{child_service.name}> provision_index: #{provision_index}")

    child_dialog_options_hash = {}
    # Set all dialog options pertaining to the catalog item plus any options destined for the catalog bundle
    unless dialogs_options_hash[0].nil?
      unless dialogs_options_hash[provision_index].nil?
        # Merge child options with global options if any
        child_dialog_options_hash = dialogs_options_hash[0].merge(dialogs_options_hash[provision_index])
      else
        child_dialog_options_hash = dialogs_options_hash[0]
      end
    else
      unless dialogs_options_hash[provision_index].nil?
        child_dialog_options_hash = dialogs_options_hash[provision_index]
      end
    end # unless dialogs_options_hash[0].nil?
    # Pass down dialog options to catalog items
    child_dialog_options_hash.each do |k,v|
      log(:info, "Adding Dialog Option: {#{k.inspect} => #{v.inspect}} to Child Service: #{child_service.name}")
      t.set_dialog_option(k, v)
    end
    log(:info, "Inspecting Child Service: #{child_service.name} Dialog Options: #{t.dialog_options.inspect}")
  end

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  @task.finished("#{err}") if @task
  exit MIQ_ABORT
end
