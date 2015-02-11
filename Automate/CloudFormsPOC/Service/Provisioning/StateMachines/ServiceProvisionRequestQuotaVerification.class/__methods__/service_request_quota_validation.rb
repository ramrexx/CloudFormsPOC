# service_request_quota_validation.rb
#
# Description: This method validates the group and/or owner quotas using the values
# [max_group_cpu, max_group_memory, max_owner_cpu, max_owner_memory]
# from values in the following order:
# 1. In the model
# 2. Group tags - This looks at the Group for the following tag values: [quota_max_cpu, quota_max_memory]
# 3. Owner tags - This looks at the User for the following tag values: [quota_max_cpu, quota_max_memory]
#

# get_options_hash - Look for service dialog variables in the dialog options hash that start with "dialog_option_[0-9]"
def get_options_hash(dialog_options)
  # Setup regular expression for service dialog tags
  options_regex = /^dialog_option_(\d*)_(.*)/i
  options_hash = {}

  # Loop through all of the options and build an options_hash from them
  dialog_options.each do |k,v|
    if options_regex =~ k
      sequence_id = $1.to_i
      option_key = $2.downcase.to_sym

      unless v.blank?
        $evm.log(:info, "Adding via regex sequence_id: #{sequence_id} option_key: #{option_key.inspect} option_value: #{v.inspect} to options_hash")
        if options_hash.has_key?(sequence_id)
          options_hash[sequence_id][option_key] = v
        else
          options_hash[sequence_id] = { option_key => v }
        end
      end
    else
      # If options_regex does not match then stuff dialog options into options_hash[0]
      sequence_id = 0
      option_key = k.downcase.to_sym

      unless v.blank?
        $evm.log(:info, "Adding sequence_id: #{sequence_id} option_key: #{option_key.inspect} v: #{v.inspect} to options_hash")
        if options_hash.has_key?(sequence_id)
          options_hash[sequence_id][option_key] = v
        else
          options_hash[sequence_id] = { option_key => v }
        end
      end
    end # if options_regex =~ k
  end # dialog_options.each do
  $evm.log(:info, "Inspecting options_hash: #{options_hash.inspect}")
  return options_hash
end

def query_prov_options(parent_service_template, prov_option)
  options_array = []
  parent_service_template.service_resources.each do |child_service_resource|

    # skip catalog item if generic for catalog bundles/items
    if parent_service_template.service_type == 'composite'
      next if child_service_resource.resource.prov_type == 'generic'
      $evm.log(:info, "Detected Service Catalog Bundle")
      child_service_resource.resource.service_resources.each do |grandchild_service_template_service_resource|
        #$evm.log(:info, "\n Inspecting grandchild_service_template_service_resource: #{grandchild_service_template_service_resource.inspect}\n")
        #$evm.log(:info, "\n Inspecting grandchild_service_template_service_resource.resource: #{grandchild_service_template_service_resource.resource.inspect}\n")
        $evm.log(:info, "Retrieving #{prov_option}=>#{grandchild_service_template_service_resource.resource.get_option(prov_option)}")
        options_array << grandchild_service_template_service_resource.resource.get_option(prov_option)
      end
    else
      next if parent_service_template.prov_type == 'generic'
      $evm.log(:info, "Detected Service Catalog Item")
      #$evm.log(:info, "\n Inspecting child_service_resource: #{child_service_resource.inspect}\n")
      #$evm.log(:info, "\n Inspecting child_service_resource.resource: #{child_service_resource.resource.inspect}\n")
      $evm.log(:info, "Retrieving #{prov_option}=>#{child_service_resource.resource.get_option(prov_option)}")
      options_array << child_service_resource.resource.get_option(prov_option)
    end
  end # parent_service_template_service_resources.each
  return options_array
end

# get_total_cpus_requested
def get_total_cpus_requested(service_template, options_hash)
  # Add up all of the :cores_per_socket from the service template(s) and the dialog options
  template_cpus_array = query_prov_options(service_template, :cores_per_socket)
  unless template_cpus_array.blank?
    template_cpu_totals = template_cpus_array.collect(&:to_i).inject(&:+)
    $evm.log(:info, "template_cpu_totals: #{template_cpu_totals.inspect}")
  end
  dialog_cpus_array = []
  options_hash.each do |sequence_id, options|
    dialog_cpus_array << options[:cores_per_socket] unless options[:cores_per_socket].blank?
  end
  unless dialog_cpus_array.blank?
    dialog_cpu_totals = dialog_cpus_array.collect(&:to_i).inject(&:+)
    $evm.log(:info, "dialog_cpu_totals: #{dialog_cpu_totals.inspect}") unless dialog_cpu_totals.zero?
  else
    dialog_cpu_totals = 0
  end

  if template_cpu_totals.to_i < dialog_cpu_totals.to_i
    total_cpus_requested = dialog_cpu_totals.to_i
  else
    total_cpus_requested = template_cpu_totals.to_i
  end
  $evm.log(:info, "total_cpus_requested: #{total_cpus_requested.inspect}")
  return total_cpus_requested
end

# get_total_memory_requested
def get_total_memory_requested(service_template, options_hash)
  # Add up all of the :vm_memory from the provisioning template(s) and the dialog options
  template_memory_array = query_prov_options(service_template, :vm_memory)
  unless template_memory_array.blank?
    $evm.log(:info, "template_memory_array: #{template_memory_array.inspect}")
    template_memory_totals = template_memory_array.collect(&:to_i).inject(&:+)
    $evm.log(:info, "template_memory_totals: #{template_memory_totals.inspect}")
  end
  dialog_memory_array = []
  options_hash.each do |sequence_id, options|
    $evm.log(:info, "sequence_id: #{sequence_id} options[:vm_memory]: #{options[:vm_memory]}")
    dialog_memory_array << options[:vm_memory] unless options[:vm_memory].blank?
  end
  unless dialog_memory_array.blank?
    dialog_memory_totals = dialog_memory_array.collect(&:to_i).inject(&:+)
    $evm.log(:info, "dialog_memory_totals: #{dialog_memory_totals.inspect}") unless dialog_memory_totals.zero?
  else
    dialog_memory_totals = 0
  end

  if template_memory_totals.to_i < dialog_memory_totals.to_i
    total_memory_requested = dialog_memory_totals.to_i
  else
    total_memory_requested = template_memory_totals.to_i
  end
  $evm.log(:info, "total_memory_requested: #{total_memory_requested}")
  return total_memory_requested
end

# check_quotas
def check_quotas(miq_request, entity, quota_hash)
  user_present = entity.ldap_group rescue nil
  if user_present.blank?
    # set group specific values
    entity_name = entity.description
    entity_type = 'Group'

    # set reason variables
    entity_cpu_reason = :group_cpu_quota_exceeded
    entity_ram_reason = :group_ram_quota_exceeded

    quota_max_cpu = nil || $evm.object['max_group_cpu'].to_i
    $evm.log(:info, "Found quota from model <max_group_cpu> with value <#{quota_max_cpu}") unless quota_max_cpu.zero?
    quota_max_memory = nil || $evm.object['max_group_memory'].to_i
    $evm.log(:info, "Found quota from model <max_group_memory> with value: #{quota_max_memory}") unless quota_max_memory.zero?
  else
    # set user specific values
    entity_name = entity.name
    entity_type = 'User'

    # set reason variables
    entity_cpu_reason = :owner_cpu_quota_exceeded
    entity_ram_reason = :owner_ram_quota_exceeded

    # Use value from model unless specified
    quota_max_cpu = nil || $evm.object['max_owner_cpu'].to_i
    $evm.log(:info, "Found quota from model <max_owner_cpu> with value <#{quota_max_cpu}") unless quota_max_cpu.zero?
    quota_max_memory = nil || $evm.object['max_owner_memory'].to_i
    $evm.log(:info, "Found quota from model <max_owner_memory> with value: #{quota_max_memory}") unless quota_max_memory.zero?
  end

  # Get the current consumption
  (entity_consumption||={})[:cpu] = entity.allocated_vcpu
  entity_consumption[:memory] = entity.allocated_memory
  entity_consumption[:vms] = entity.vms.count
  entity_consumption[:allocated_storage] = entity.allocated_storage
  entity_consumption[:provisioned_storage] = entity.provisioned_storage
  $evm.log(:info, "#{entity_type}: #{entity_name} current vCPU allocated: #{entity_consumption[:cpu]}")
  $evm.log(:info, "#{entity_type}: #{entity_name} current vRAM allocated (bytes): #{entity_consumption[:memory]} current vRAM allocated (megabytes): #{entity_consumption[:memory] / 1024**2}")
  $evm.log(:info, "#{entity_type}: #{entity_name} current VMs: #{entity_consumption[:vms]}")
  $evm.log(:info, "#{entity_type}: #{entity_name} current Storage Allocated (bytes): #{entity_consumption[:allocated_storage]}")
  $evm.log(:info, "#{entity_type}: #{entity_name} current Storage Provisioned (bytes): #{entity_consumption[:provisioned_storage]}")

  ##########
  # CPU Quota Check
  ##########
  $evm.log(:info, "#{entity_type}: #{entity_name} current vCPU allocated: #{entity_consumption[:cpu]}")
  # If is entity tagged with quota_max_cpu then override model
  tag_max_cpu = entity.tags(:quota_max_cpu).first
  unless tag_max_cpu.nil?
    quota_max_cpu = tag_max_cpu.to_i
    $evm.log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_max_cpu with value: #{quota_max_cpu}")
  end
  # Validate CPU Quota
  unless quota_max_cpu.zero?
    if entity_consumption && (entity_consumption[:cpu] + quota_hash[:total_cpus_requested] > quota_max_cpu)
      $evm.log(:info, "#{entity_type}: #{entity_name} vCPUs allocated: #{entity_consumption[:cpu]} + requested: #{quota_hash[:total_cpus_requested]} exceeds quota: #{quota_max_cpu}")
      quota_hash[:quota_exceeded] = true
      quota_hash[entity_cpu_reason] = "#{entity_type} vCPUs #{entity_consumption[:cpu]} + requested #{quota_hash[:total_cpus_requested]} &gt; quota #{quota_max_cpu}"
    end
  end

  ##########
  # Memory Quota Check
  ##########
  $evm.log(:info, "#{entity_type}: #{entity_name} current vRAM allocated (megabytes): #{entity_consumption[:memory] / 1024**2}")
  # If group is tagged then override
  tag_max_group_memory = entity.tags(:quota_max_memory).first
  unless tag_max_group_memory.nil?
    quota_max_memory = tag_max_group_memory.to_i
    $evm.log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_max_memory with value: #{quota_max_memory}")
  end
  # Validate Group Memory Quota
  unless quota_max_memory.zero?
    if entity_consumption && (entity_consumption[:memory] / 1024**2 + quota_hash[:total_memory_requested] > quota_max_memory)
      $evm.log(:info, "#{entity_type}: #{entity_name} current vRAM allocated (megabytes): #{entity_consumption[:memory] / 1024**2} + requested: #{quota_hash[:total_memory_requested]} exceeds quota: #{quota_max_memory}")
      quota_hash[:quota_exceeded] = true
      quota_hash[entity_ram_reason] = "#{entity_type} - vRAM #{entity_consumption[:memory] / 1024**2} + requested #{quota_hash[:total_memory_requested]} &gt; quota #{quota_max_memory}"
    end
  end
end

# get the request object from root
miq_request = $evm.root['miq_request']
$evm.log(:info, "miq_request.id: #{miq_request.id} miq_request.options[:dialog]: #{miq_request.options[:dialog].inspect}")

# Get dialog options from miq_request
dialog_options = miq_request.options[:dialog]
$evm.log(:info, "Inspecting Dialog Options: #{dialog_options.inspect}")
options_hash = get_options_hash(dialog_options)

# lookup the service_template object
service_template = $evm.vmdb(miq_request.source_type, miq_request.source_id)
$evm.log(:info, "service_template id: #{service_template.id} service_type: #{service_template.service_type} description: #{service_template.description} services: #{service_template.service_resources.count}")

# get the user and group objects
#user = $evm.root['user']
user = miq_request.requester
group = user.current_group

(quota_hash||={})[:quota_exceeded] = false
quota_hash[:total_cpus_requested] = get_total_cpus_requested(service_template, options_hash)
quota_hash[:total_memory_requested] = get_total_memory_requested(service_template, options_hash)
$evm.log(:info, "Inspecting quota_hash: #{quota_hash}")

# exit if no work is needed
exit MIQ_OK if quota_hash[:total_cpus_requested].zero? && quota_hash[:total_memory_requested].zero?

# specify whether quotas should be managed by group or user or both (valid options are [true | false | 'both'])
manage_quotas_by_group = true

if manage_quotas_by_group || manage_quotas_by_group == 'both'
  check_quotas(miq_request, group, quota_hash)
end
if manage_quotas_by_group == false || manage_quotas_by_group == 'both'
  check_quotas(miq_request, user, quota_hash)
end

$evm.log(:info, "quota_hash: #{quota_hash.inspect}")
if quota_hash[:quota_exceeded]
  quota_message = "Service request denied due to the following quota limits:"
  quota_message += "(#{quota_hash[:group_cpu_quota_exceeded]}}) " unless quota_hash[:group_cpu_quota_exceeded].blank?
  quota_message += "(#{quota_hash[:group_ram_quota_exceeded]}}) " unless quota_hash[:group_ram_quota_exceeded].blank?
  quota_message += "(#{quota_hash[:owner_cpu_quota_exceeded]}}) " unless quota_hash[:owner_cpu_quota_exceeded].blank?
  quota_message += "(#{quota_hash[:owner_ram_quota_exceeded]}}) " unless quota_hash[:owner_ram_quota_exceeded].blank?
  $evm.log(:info, "Inspecting quota_message: #{quota_message}")

  miq_request.set_message(quota_message[0..250])
  $evm.root['ae_result'] = 'error'
  $evm.object['reason'] = quota_message
end
