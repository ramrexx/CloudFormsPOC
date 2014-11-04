#
# CatalogItemInitialization.rb
#
# Description: This method Performs the following functions:
# 1. Look for all Service Dialog Options in the $evm.root['service_template_provision_task'].dialog_options
# 2. Set the name of the service
# 3. Set tags on the service
# 4. Set retirement on the service
# 5. Override miq_provision task with any options and tags
#

def log(level, msg, update_message=false)
  $evm.log(level, "#{msg}")
  $evm.root['service_template_provision_task'].message = msg if $evm.root['service_template_provision_task'] && update_message
end

# Look for service dialog variables in the dialog options hash that start with "dialog_tag_[0-9]",
def get_dialog_tags_hash(dialog_options)
  log(:info, "Processing get_dialog_tags_hash...", true)
  dialogs_tags_hash = {}

  dialog_tags_regex = /^dialog_tag_(\d*)_(.*)/
  # Loop through all of the tags and build dialogs_tags_hash
  dialog_options.each do |k, v|
    next if v.blank?
    if dialog_tags_regex =~ k
      build = $1.to_i
      tag_category = $2.to_sym
      tag_value = v.downcase
      #log(:info, "build: #{build} Adding tag: {#{tag_category.inspect} => #{tag_value.inspect}} to dialogs_tags_hash")
      (dialogs_tags_hash[build] ||={})[tag_category] = tag_value
    end
  end
  log(:info, "Inspecting dialogs_tags_hash: #{dialogs_tags_hash.inspect}")
  log(:info, "Processing get_dialog_tags_hash...Complete", true)
  return dialogs_tags_hash
end

# Look for service dialog variables in the dialog options hash that start with "dialog_option_[0-9]",
def get_dialog_options_hash(dialog_options)
  log(:info, "Processing get_dialog_options_hash...", true)
  dialogs_options_hash = {}

  dialog_options_regex = /^dialog_option_(\d*)_(.*)/
  # Loop through all of the options and build dialogs_options_hash
  dialog_options.each do |k, v|
    next if v.blank?
    if dialog_options_regex =~ k
      build = $1.to_i
      option_key = $2.to_sym
      option_value = v
      #log(:info, "build: #{build} Adding option: {#{option_key.inspect} => #{option_value.inspect}} to dialogs_options_hash")
      (dialogs_options_hash[build] ||={})[option_key] = option_value
    else
      # If dialog_options_regex does not match then stuff option into dialogs_options_hash
      build = 0
      option_key = k.downcase.to_sym
      option_value = v
      #log(:info, "build: #{build} Adding option: {#{option_key.inspect} => #{option_value.inspect}} to dialogs_options_hash")
      (dialogs_options_hash[build] ||={})[option_key] = option_value
    end
  end
  log(:info, "Inspecting dialogs_options_hash: #{dialogs_options_hash.inspect}")
  log(:info, "Processing get_dialog_options_hash...Complete", true)
  return dialogs_options_hash
end

# Loop through all tags from the dialog and create the categories and tags automatically
def process_tags(category, single_value, tag)
  # Convert to lower case and replace all non-word characters with underscores
  category_name = category.to_s.downcase.gsub(/\W/,'_')
  tag_name = tag.to_s.downcase.gsub(/\W/,'_')
  # if the category exists else create it
  unless $evm.execute('category_exists?', category_name)
    log(:info, "Creating Category: {#{category_name} => #{category}}")
    $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category}")
  end
  # if the tag exists else create it
  unless $evm.execute('tag_exists?', category_name, tag_name)
    log(:info, "Creating tag: {#{tag_name} => #{tag}}")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag}")
  end
end

# service_naming - name the service
def service_naming(service, dialogs_tags_hash, dialogs_options_hash)
  log(:info, "Processing service_naming...", true)
  new_service_name = dialogs_options_hash[0][:dialog_service_name] rescue nil
  new_service_description = dialogs_options_hash[0][:dialog_service_description] rescue nil

  if new_service_name.blank?
    new_service_name = "#{service.name}-#{Time.now.strftime('%Y%m%d-%H%M%S')}"
  end
  log(:info, "Service name: #{new_service_name}")
  service.name = new_service_name

  unless new_service_description.blank?
    log(:info, "Service description #{new_service_description}")
    service.description = new_service_description
  end
  log(:info, "Processing service_naming...Complete", true)
end

# service_tagging - tag the parent service with tags in dialogs_tags_hash
def service_tagging(service, dialogs_tags_hash)
  log(:info, "Processing service_tagging...", true)
  unless dialogs_tags_hash[0].nil?
    dialogs_tags_hash[0].each do |k, v|
      log(:info, "Adding Tag: {#{k.inspect} => #{v.inspect}} to Service:<#{service.name}>")
      process_tags( k, true, v )
      service.tag_assign("#{k}/#{v}")
    end
  end
  log(:info, "Processing service_tagging...Complete", true)
end

# service_retirement - default the service retirement
def service_retirement(service, dialogs_tags_hash, dialogs_options_hash)
  log(:info, "Processing service_retirement...", true)

  new_service_retirement = dialogs_options_hash[0][:dialog_service_retirement] rescue nil
  new_service_retirement_warning = dialogs_options_hash[0][:dialog_service_retirement_warning] rescue nil

  if new_service_retirement.nil?
    # service retirement based tag
    service_retirement_tag = dialogs_tags_hash[0][:environment] rescue nil
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
    service.retires_on = new_service_retirement.to_date
    service.retirement_warn = new_service_retirement_warning.to_i unless new_service_retirement_warning.nil?
  end
  log(:info, "Service: #{service.name} retires_on: #{service.retires_on} retirement_warn: #{service.retirement_warn}")
  log(:info, "Processing service_retirement...Complete", true)
end

# use this to name the vm from matching_options_hash[:vm_name] || matching_options_hash[:vm_target_name]
def get_vm_name(matching_options_hash, matching_tags_hash, prov)
  log(:info, "Processing get_vm_name", true)
  new_vm_name = matching_options_hash[:vm_name] || matching_options_hash[:vm_target_name] rescue nil
  unless new_vm_name.blank?
    matching_options_hash[:vm_target_name] = new_vm_name
    matching_options_hash[:vm_target_hostname] = new_vm_name
    matching_options_hash[:vm_name] = new_vm_name
  else
    matching_options_hash[:vm_target_hostname] = prov.get_option(:vm_target_name)
    matching_options_hash[:vm_name] = prov.get_option(:vm_target_name)
  end
  log(:info, "Processing get_vm_name...Complete", true)
end

# get vCPU/vRAM/flavor based on flavor|sizing parameter
def get_sizing(matching_options_hash, matching_tags_hash, prov)
  log(:info, "Processing get_sizing...", true)
  flavor_sizing = matching_options_hash[:flavor] || matching_options_hash[:sizing] rescue nil
  return if flavor_sizing.blank?

  case flavor_sizing
  when 'xsmall'
    # 1 X .5
    matching_options_hash[:cores_per_socket] = '1'
    matching_options_hash[:vm_memory] = '512'
  when 'small'
    # 1 X 1
    matching_options_hash[:cores_per_socket] = '1'
    matching_options_hash[:vm_memory] = '1024'
  when 'medium'
    # 2 X 2
    matching_options_hash[:cores_per_socket] = '2'
    matching_options_hash[:vm_memory] = '2048'
  when 'large'
    # 2 X 4
    matching_options_hash[:cores_per_socket] = '2'
    matching_options_hash[:vm_memory] = '4096'
  when 'xlarge'
    # 4 X 4
    matching_options_hash[:cores_per_socket] = '4'
    matching_options_hash[:vm_memory] = '4096'
  when 'xxlarge'
    # 4 X 6
    matching_options_hash[:cores_per_socket] = '4'
    matching_options_hash[:vm_memory] = '6144'
  when 'xxxlarge'
    # 8 X 8
    matching_options_hash[:cores_per_socket] = '8'
    matching_options_hash[:vm_memory] = '8192'
  else
    # Set default flavors here
  end
  matching_tags_hash[:flavor] = flavor_sizing
  log(:info, "Processing get_sizing...Complete", true)
end

# Get destination service object
service = $evm.root['service_template_provision_task'].destination
log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{$evm.root['service_template_provision_task'].miq_request_tasks.count}>")

# Get dialog options from task
dialog_options = $evm.root['service_template_provision_task'].dialog_options
log(:info, "dialog_options: #{dialog_options.inspect}")

# Build dialogs_tags_hash
dialogs_tags_hash = get_dialog_tags_hash(dialog_options)

# Build dialogs_options_hash
dialogs_options_hash = get_dialog_options_hash(dialog_options)

# Service naming
service_naming(service, dialogs_tags_hash, dialogs_options_hash)

# Tag Service
service_tagging(service, dialogs_tags_hash)

# Set Service Retirement
service_retirement(service, dialogs_tags_hash, dialogs_options_hash)

matching_options_hash = {}
matching_tags_hash = {}

# merge build 0 hash
dialogs_options_hash.each do |build, options|
  unless dialogs_options_hash[0].nil?
    matching_options_hash = dialogs_options_hash[0].merge(dialogs_options_hash[build] || {})
  else
    matching_options_hash = dialogs_options_hash[build] || {}
  end
  unless dialogs_tags_hash[0].nil?
    matching_tags_hash = dialogs_tags_hash[0].merge(dialogs_tags_hash[build] || {})
  else
    matching_tags_hash = dialogs_tags_hash[build] || {}
  end
end

$evm.root['service_template_provision_task'].miq_request_tasks.each do |t|
  # Child Service
  child_service = t.destination
  log(:info, "Child Service: #{child_service.name}")

  next if t.miq_request_tasks.nil?
  # Loop through each child provisioning object and apply tags and options
  t.miq_request_tasks.each do |prov|
    log(:info, "Grandchild Task Id: #{prov.id} Description: #{prov.description} source type: #{prov.source_type}")
    # Get vm_name
    get_vm_name(matching_options_hash, matching_tags_hash, prov)
    # Get sizing/flavor
    get_sizing(matching_options_hash, matching_tags_hash, prov)

    # Add all tags to miq_provision
    matching_tags_hash.each do |k, v|
      log(:info, "Adding Tag: {#{k.inspect} => #{v.inspect}} to Provisioning Id: #{prov.id}")
      process_tags( k, true, v )
      prov.add_tag(k, v)
    end

    # Add all options to miq_provision
    matching_options_hash.each do |k, v|
      log(:info, "Adding Option: {#{k.inspect} => #{v.inspect}} to Provisioning Id: #{prov.id}")
      prov.set_option(k, v)
    end
  end # t.miq_request_tasks.each
end # $evm.root['service_template_provision_task'].miq_request_tasks.each do
