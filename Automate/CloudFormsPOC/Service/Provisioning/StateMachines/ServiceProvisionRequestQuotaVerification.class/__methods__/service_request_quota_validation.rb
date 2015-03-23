# service_request_quota_validation.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method validates the group and/or owner quotas in the following order:
# 1. Group model - This looks at the Instance for the following attributes: [max_group_cpu, warn_group_cpu, max_group_memory, warn_group_memory, max_group_storage, warn_group_storage, max_group_vms, warn_group_vms]
# 2. Group tags - This looks at the Group for the following tag values: [quota_max_cpu, quota_warn_cpu, quota_max_memory, quota_warn_memory, quota_max_storage, quota_warn_storage, quota_max_vms, quota_warn_vms]
# 3. Owner model - This looks at the Instance for the following attributes: [max_owner_cpu, warn_owner_cpu, max_owner_memory, warn_owner_memory, max_owner_storage, warn_owner_storage, max_owner_vms, warn_owner_vms]
# 4. User tags - This looks at the User for the following tag values: [quota_max_cpu, quota_warn_cpu, quota_max_memory, quota_warn_memory, quota_max_storage, quota_warn_storage, quota_max_vms, quota_warn_vms]
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

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
          log(:info, "Adding via regex sequence_id: #{sequence_id} option_key: #{option_key.inspect} option_value: #{v.inspect} to options_hash")
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
          log(:info, "Adding sequence_id: #{sequence_id} option_key: #{option_key.inspect} v: #{v.inspect} to options_hash")
          if options_hash.has_key?(sequence_id)
            options_hash[sequence_id][option_key] = v
          else
            options_hash[sequence_id] = { option_key => v }
          end
        end
      end # if options_regex =~ k
    end # dialog_options.each do
    log(:info, "Inspecting options_hash: #{options_hash.inspect}")
    return options_hash
  end

  def query_prov_options(prov_option, options_array=[])
    @service_template.service_resources.each do |child_service_resource|
      # skip catalog item if generic
      if @service_template.service_type == 'composite'
        next if child_service_resource.resource.prov_type == 'generic'
        child_service_resource.resource.service_resources.each do |grandchild_service_template_service_resource|
          if prov_option == :allocated_storage
            template = $evm.vmdb(:miq_template).find_by_id(grandchild_service_template_service_resource.resource.get_option(:src_vm_id))
            if template
              log(:info, "Retrieving template #{template.name} allocated_disk_storage => #{template.allocated_disk_storage} from Service Catalog Bundle")
              options_array << template.allocated_disk_storage
              # log(:info, "Retrieving template #{template.name} provisioned_storage => #{template.provisioned_storage} from Service Catalog Bundle")
              # options_array << template.provisioned_storage
            end
          else
            log(:info, "Retrieving #{prov_option}=>#{grandchild_service_template_service_resource.resource.get_option(prov_option)} from Service Catalog Bundle")
            options_array << grandchild_service_template_service_resource.resource.get_option(prov_option)
          end
        end
      else
        next if @service_template.prov_type == 'generic'
        if prov_option == :allocated_storage
          template = $evm.vmdb(:miq_template).find_by_id(child_service_resource.resource.get_option(:src_vm_id))
          if template
            log(:info, "Retrieving template #{template.name} allocated_disk_storage => #{template.allocated_disk_storage} from Service Catalog Item")
            options_array << template.allocated_disk_storage
            # log(:info, "Retrieving template #{template.name} provisioned_storage => #{template.provisioned_storage} from Service Catalog Bundle")
            # options_array << template.provisioned_storage
          end
        else
          log(:info, "Retrieving #{prov_option}=>#{child_service_resource.resource.get_option(prov_option)} from Service Catalog Item")
          options_array << child_service_resource.resource.get_option(prov_option)
        end
      end
    end
    return options_array
  end

  def get_total_requested(options_hash, prov_option)
    template_array = query_prov_options(prov_option)
    unless template_array.blank?
      template_totals = template_array.collect(&:to_i).inject(&:+)
      log(:info, "template_totals(#{prov_option.to_sym}): #{template_totals.inspect}")
    end
    dialog_array = []
    options_hash.each do |sequence_id, options|
      dialog_array << options[prov_option] unless options[prov_option].blank?
    end
    unless dialog_array.blank?
      dialog_totals = dialog_array.collect(&:to_i).inject(&:+)
      log(:info, "dialog_totals(#{prov_option.to_sym}): #{dialog_totals.inspect}") unless dialog_totals.zero?
    end
    if template_totals.to_i < dialog_totals.to_i
      total_requested = dialog_totals.to_i
    else
      total_requested = template_totals.to_i
    end
    log(:info, "total_requested(#{prov_option.to_sym}): #{total_requested.inspect}")
    return total_requested
  end

  def check_quotas(entity, quota_hash)
    unless entity.respond_to?('ldap_group')
      # set group specific values
      entity_name = entity.description
      entity_type = 'Group'
      # set reason variables
      entity_cpu_reason           = :group_cpu_quota_exceeded
      entity_warn_cpu_reason      = :group_warn_cpu_quota_exceeded
      entity_ram_reason           = :group_ram_quota_exceeded
      entity_warn_ram_reason      = :group_warn_ram_quota_exceeded
      entity_vms_reason           = :group_vms_quota_exceeded
      entity_warn_vms_reason      = :group_warn_vms_quota_exceeded
      entity_storage_reason       = :group_storage_quota_exceeded
      entity_warn_storage_reason  = :group_warn_storage_quota_exceeded
      quota_max_cpu = nil || $evm.object['max_group_cpu'].to_i
      log(:info, "Found quota from model <max_group_cpu> with value #{quota_max_cpu}") unless quota_max_cpu.zero?
      quota_warn_cpu = nil || $evm.object['warn_group_cpu'].to_i
      log(:info, "Found quota from model <warn_group_cpu> with value #{quota_warn_cpu}") unless quota_warn_cpu.zero?
      quota_max_memory = nil || $evm.object['max_group_memory'].to_i
      log(:info, "Found quota from model <max_group_memory> with value: #{quota_max_memory}") unless quota_max_memory.zero?
      quota_warn_memory = nil || $evm.object['warn_group_memory'].to_i
      log(:info, "Found quota from model <warn_group_memory> with value: #{quota_warn_memory}") unless quota_warn_memory.zero?
      quota_max_storage = nil || $evm.object['max_group_storage'].to_i
      log(:info, "Found quota from model <max_group_storage> with value: #{quota_max_storage}") unless quota_max_storage.zero?
      quota_warn_storage = nil || $evm.object['warn_group_storage'].to_i
      log(:info, "Found quota from model <warn_group_storage> with value: #{quota_warn_storage}") unless quota_warn_storage.zero?
      quota_max_vms = nil || $evm.object['max_group_vms'].to_i
      log(:info, "Found quota from model <max_group_vms> with value #{quota_max_vms}") unless quota_max_vms.zero?
      quota_warn_vms = nil || $evm.object['warn_group_vms'].to_i
      log(:info, "Found quota from model <warn_group_vms> with value #{quota_warn_vms}") unless quota_warn_vms.zero?
    else
      # set user specific values
      entity_name = entity.name
      entity_type = 'User'
      # set reason variables
      entity_cpu_reason           = :owner_cpu_quota_exceeded
      entity_warn_cpu_reason      = :owner_warn_cpu_quota_exceeded
      entity_ram_reason           = :owner_ram_quota_exceeded
      entity_warn_ram_reason      = :owner_warn_ram_quota_exceeded
      entity_vms_reason           = :owner_vms_quota_exceeded
      entity_warn_vms_reason      = :owner_warn_vms_quota_exceeded
      entity_storage_reason       = :owner_storage_quota_exceeded
      entity_warn_storage_reason  = :owner_warn_storage_quota_exceeded
      # Use value from model unless specified
      quota_max_cpu = nil || $evm.object['max_owner_cpu'].to_i
      log(:info, "Found quota from model <max_owner_cpu> with value #{quota_max_cpu}") unless quota_max_cpu.zero?
      quota_warn_cpu = nil || $evm.object['warn_owner_cpu'].to_i
      log(:info, "Found quota from model <warn_owner_cpu> with value #{quota_warn_cpu}") unless quota_warn_cpu.zero?
      quota_max_memory = nil || $evm.object['max_owner_memory'].to_i
      log(:info, "Found quota from model <max_owner_memory> with value: #{quota_max_memory}") unless quota_max_memory.zero?
      quota_warn_memory = nil || $evm.object['warn_owner_memory'].to_i
      log(:info, "Found quota from model <warn_owner_memory> with value: #{quota_warn_memory}") unless quota_warn_memory.zero?
      quota_max_storage = nil || $evm.object['max_owner_storage'].to_i
      log(:info, "Found quota from model <max_owner_storage> with value: #{quota_max_storage}") unless quota_max_storage.zero?
      quota_warn_storage = nil || $evm.object['warn_owner_storage'].to_i
      log(:info, "Found quota from model <warn_owner_storage> with value: #{quota_warn_storage}") unless quota_warn_storage.zero?
      quota_max_vms = nil || $evm.object['max_owner_vms'].to_i
      log(:info, "Found quota from model <max_owner_vms> with value #{quota_max_vms}") unless quota_max_vms.zero?
      quota_warn_vms = nil || $evm.object['warn_owner_vms'].to_i
      log(:info, "Found quota from model <warn_owner_vms> with value #{quota_warn_vms}") unless quota_warn_vms.zero?
    end

    # Get the current consumption
    (entity_consumption||={})[:cpu]           = entity.allocated_vcpu
    entity_consumption[:memory]               = entity.allocated_memory
    # count all entity vms that are not archived
    entity_consumption[:vms]                  = entity.vms.select {|vm| vm.id if ! vm.archived }.count
    entity_consumption[:allocated_storage]    = entity.allocated_storage
    entity_consumption[:provisioned_storage]  = entity.provisioned_storage
    # log(:info, "#{entity_type}: #{entity_name} current Storage Provisioned (bytes): #{entity_consumption[:provisioned_storage]}")

    # CPU Quota Check
    log(:info, "#{entity_type}: #{entity_name} current vCPU allocated: #{entity_consumption[:cpu]}")
    # If is entity tagged with quota_max_cpu then override model
    tag_max_cpu = entity.tags(:quota_max_cpu).first
    unless tag_max_cpu.nil?
      quota_max_cpu = tag_max_cpu.to_i
      log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_max_cpu with value: #{quota_max_cpu}")
    end
    # Validate CPU Quota
    unless quota_max_cpu.zero?
      if entity_consumption && (entity_consumption[:cpu] + quota_hash[:total_cpus_requested] > quota_max_cpu)
        log(:info, "#{entity_type}: #{entity_name} vCPUs allocated: #{entity_consumption[:cpu]} + requested: #{quota_hash[:total_cpus_requested]} exceeds quota: #{quota_max_cpu}")
        quota_hash[:quota_exceeded] = true
        quota_hash[entity_cpu_reason] = "#{entity_type} vCPUs #{entity_consumption[:cpu]} + requested #{quota_hash[:total_cpus_requested]} &gt; quota #{quota_max_cpu}"
      end
    end
    # If entity tagged with quota_warn_cpu then override model
    tag_warn_cpu = entity.tags(:quota_warn_cpu).first
    unless tag_warn_cpu.nil?
      quota_warn_cpu = tag_warn_cpu.to_i
      log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_warn_cpu with value: #{quota_warn_cpu}")
    end
    # Validate CPU Warn Quota
    unless quota_warn_cpu.zero?
      if entity_consumption && (entity_consumption[:cpu] + quota_hash[:total_cpus_requested] > quota_warn_cpu)
        log(:info, "#{entity_type}: #{entity_name} vCPUs allocated: #{entity_consumption[:cpu]} + requested: #{quota_hash[:total_cpus_requested]} exceeds warn quota: #{quota_warn_cpu}")
        quota_hash[:quota_warn_exceeded] = true
        quota_hash[entity_warn_cpu_reason] = "#{entity_type} vCPUs #{entity_consumption[:cpu]} + requested #{quota_hash[:total_cpus_requested]} &gt; warn quota #{quota_warn_cpu}"
      end
    end

    # Memory Quota Check
    log(:info, "#{entity_type}: #{entity_name} current vRAM allocated: #{entity_consumption[:memory]}(bytes) current vRAM allocated: #{entity_consumption[:memory] / 1024**2}MB")
    # If entity is tagged then override
    tag_max_memory = entity.tags(:quota_max_memory).first
    unless tag_max_memory.nil?
      quota_max_memory = tag_max_memory.to_i
      log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_max_memory with value: #{quota_max_memory}")
    end
    # Validate Memory Quota
    unless quota_max_memory.zero?
      if entity_consumption && (entity_consumption[:memory] / 1024**2 + quota_hash[:total_memory_requested] > quota_max_memory)
        log(:info, "#{entity_type}: #{entity_name} current vRAM allocated: #{entity_consumption[:memory] / 1024**2}MB + requested: #{quota_hash[:total_memory_requested]}MB exceeds quota: #{quota_max_memory}MB")
        quota_hash[:quota_exceeded] = true
        quota_hash[entity_ram_reason] = "#{entity_type} - vRAM #{entity_consumption[:memory] / 1024**2} + requested #{quota_hash[:total_memory_requested]} &gt; quota #{quota_max_memory}"
      end
    end
    # If entity tagged with quota_warn_memory then override model
    tag_warn_memory = entity.tags(:quota_warn_memory).first
    unless tag_warn_memory.nil?
      quota_warn_memory = tag_warn_memory.to_i
      log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_warn_memory with value: #{quota_warn_memory}")
    end
    # Validate Memory Warn Quota
    unless quota_warn_memory.zero?
      if entity_consumption && (entity_consumption[:memory] / 1024**2 + quota_hash[:total_memory_requested] > quota_warn_memory)
        log(:info, "#{entity_type}: #{entity_name} current vRAM allocated: #{entity_consumption[:memory] / 1024**2}MB + requested: #{quota_hash[:total_memory_requested]}MB exceeds warn quota: #{quota_warn_memory}MB")
        quota_hash[:quota_warn_exceeded] = true
        quota_hash[entity_warn_ram_reason] = "#{entity_type} - vRAM #{entity_consumption[:memory] / 1024**2} + requested #{quota_hash[:total_memory_requested]} &gt; warn quota #{quota_warn_memory}"
      end
    end

    # Storage Quota Check
    log(:info, "#{entity_type}: #{entity_name} current storage allocated: #{entity_consumption[:allocated_storage]}(bytes) current storage allocated: #{entity_consumption[:allocated_storage] / 1024**3}GB")
    # If entity is tagged then override
    tag_max_storage = entity.tags(:quota_max_storage).first
    unless tag_max_storage.nil?
      quota_max_storage = tag_max_storage.to_i
      log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_max_storage with value: #{quota_max_storage}")
    end
    # Validate Storage Quota
    unless quota_max_storage.zero?
      if entity_consumption && (entity_consumption[:allocated_storage] + quota_hash[:total_storage_requested] / 1024**3 > quota_max_storage)
        log(:info, "#{entity_type}: #{entity_name} current storage allocated: #{entity_consumption[:allocated_storage] / 1024**3}GB + requested: #{quota_hash[:total_storage_requested] / 1024**3}GB exceeds quota: #{quota_max_storage}GB")
        quota_hash[:quota_exceeded] = true
        quota_hash[entity_storage_reason] = "#{entity_type} - storage #{entity_consumption[:allocated_storage] / 1024**2} + requested #{quota_hash[:total_storage_requested]} &gt; quota #{quota_max_storage}GB"
      end
    end
    # If entity tagged with quota_warn_storage then override model
    tag_warn_storage = entity.tags(:quota_warn_storage).first
    unless tag_warn_storage.nil?
      quota_warn_storage = tag_warn_storage.to_i
      log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_warn_storage with value: #{tag_warn_storage}")
    end
    # Validate Storage Warn Quota
    unless quota_warn_storage.zero?
      if entity_consumption && (entity_consumption[:allocated_storage] / 1024**3 + quota_hash[:total_storage_requested] / 1024**3 > quota_warn_storage)
        log(:info, "#{entity_type}: #{entity_name} current storage allocated: #{entity_consumption[:allocated_storage] / 1024**3}GB + requested: #{quota_hash[:total_storage_requested]}GB exceeds warn quota: #{quota_warn_storage}GB")
        quota_hash[:quota_warn_exceeded] = true
        quota_hash[entity_warn_storage_reason] = "#{entity_type} - storage #{entity_consumption[:allocated_storage] / 1024**3}GB + requested #{quota_hash[:total_storage_requested]}GB &gt; warn quota #{quota_warn_storage}GB"
      end
    end

    # VMs Quota Check
    log(:info, "#{entity_type}: #{entity_name} current VMs allocated: #{entity_consumption[:vms]}")
    # If group is tagged then override
    tag_max_vms = entity.tags(:quota_max_vms).first
    unless tag_max_vms.nil?
      quota_max_vms = tag_max_vms.to_i
      log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_max_vms with value: #{quota_max_vms}")
    end
    # Validate Group Memory Quota
    unless quota_max_vms.zero?
      if entity_consumption && (entity_consumption[:vms] + quota_hash[:total_vms_requested] > quota_max_vms)
        log(:info, "#{entity_type}: #{entity_name} current VMs allocated: #{entity_consumption[:vms]} + requested: #{quota_hash[:total_vms_requested]} exceeds quota: #{quota_max_vms}")
        quota_hash[:quota_exceeded] = true
        quota_hash[entity_vms_reason] = "#{entity_type} - VMs #{entity_consumption[:vms]} + requested #{quota_hash[:total_vms_requested]} &gt; quota #{quota_max_vms}"
      end
    end
    # If entity tagged with quota_warn_memory then override model
    tag_warn_vms = entity.tags(:quota_warn_vms).first
    unless tag_warn_vms.nil?
      quota_warn_vms = tag_warn_vms.to_i
      log(:info, "#{entity_type}: #{entity_name} overriding quota from #{entity_type} tag: quota_warn_vms with value: #{quota_warn_vms}")
    end
    # Validate Group Memory Quota
    unless quota_warn_vms.zero?
      if entity_consumption && (entity_consumption[:vms] + quota_hash[:total_vms_requested] > quota_warn_vms)
        log(:info, "#{entity_type}: #{entity_name} current VMs allocated: #{entity_consumption[:vms]} + requested: #{quota_hash[:total_vms_requested]} exceeds warn quota: #{quota_warn_vms}")
        quota_hash[:quota_warn_exceeded] = true
        quota_hash[entity_warn_vms_reason] = "#{entity_type} - VMs #{entity_consumption[:vms]} + requested #{quota_hash[:total_vms_requested]} &gt; warn quota #{quota_warn_vms}"
      end
    end
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # get the request object from root
  @miq_request = $evm.root['miq_request']
  log(:info, "Request id: #{@miq_request.id} options: #{@miq_request.options.inspect}")

  # Get dialog options from miq_request
  dialog_options = @miq_request.options[:dialog]
  log(:info, "Inspecting Dialog Options: #{dialog_options.inspect}")
  options_hash = get_options_hash(dialog_options)

  # lookup the service_template object
  @service_template = $evm.vmdb(@miq_request.source_type, @miq_request.source_id)
  log(:info, "service_template id: #{@service_template.id} service_type: #{@service_template.service_type} description: #{@service_template.description} services: #{@service_template.service_resources.count}")

  # get the user and group objects
  user = @miq_request.requester
  group = user.current_group

  (quota_hash||={})[:quota_exceeded]    = false
  quota_hash[:quota_warn_exceeded]      = false
  quota_hash[:total_cpus_requested]     = get_total_requested(options_hash, :cores_per_socket)
  quota_hash[:total_memory_requested]   = get_total_requested(options_hash, :vm_memory)
  quota_hash[:total_storage_requested]  = get_total_requested(options_hash, :allocated_storage)
  # quota_hash[:total_storage_requested]  = get_total_requested(options_hash, :provisioned_storage)
  quota_hash[:total_vms_requested]      = get_total_requested(options_hash, :number_of_vms)
  log(:info, "Inspecting quota_hash: #{quota_hash}")

  # specify whether quotas should be managed by group or user or both (valid options are [true | false | 'both'])
  manage_quotas_by_group = $evm.object['manage_quotas_by_group'] || true
  if manage_quotas_by_group =~ (/(both|true|t|yes|y|1)$/i)
    check_quotas(group, quota_hash)
  end
  if manage_quotas_by_group =~ (/(both|false|f|no|n|0)$/i)
    check_quotas(user, quota_hash)
  end

  log(:info, "quota_hash: #{quota_hash.inspect}")
  if quota_hash[:quota_exceeded]
    quota_message = "Service request denied due to the following quota limits:"
    quota_message += "(#{quota_hash[:group_cpu_quota_exceeded]}}) "     if quota_hash[:group_cpu_quota_exceeded]
    quota_message += "(#{quota_hash[:group_ram_quota_exceeded]}}) "     if quota_hash[:group_ram_quota_exceeded]
    quota_message += "(#{quota_hash[:group_storage_quota_exceeded]}}) " if quota_hash[:group_storage_quota_exceeded]
    quota_message += "(#{quota_hash[:group_vms_quota_exceeded]}}) "     if quota_hash[:group_vms_quota_exceeded]
    quota_message += "(#{quota_hash[:owner_cpu_quota_exceeded]}}) "     if quota_hash[:owner_cpu_quota_exceeded]
    quota_message += "(#{quota_hash[:owner_ram_quota_exceeded]}}) "     if quota_hash[:owner_ram_quota_exceeded]
    quota_message += "(#{quota_hash[:owner_storage_quota_exceeded]}}) " if quota_hash[:owner_storage_quota_exceeded]
    quota_message += "(#{quota_hash[:owner_vms_quota_exceeded]}}) "     if quota_hash[:owner_vms_quota_exceeded]
    log(:info, "Inspecting quota_message: #{quota_message}")
    @miq_request.set_message(quota_message[0..250])
    @miq_request.set_option(:service_quota_exceeded, quota_message)
    $evm.root['ae_result'] = 'error'
    $evm.object['reason'] = quota_message
  elsif quota_hash[:quota_warn_exceeded]
    quota_message = "Service request warning due to the following quota thresholds:"
    quota_message += "(#{quota_hash[:group_warn_cpu_quota_exceeded]}}) "      if quota_hash[:group_warn_cpu_quota_exceeded]
    quota_message += "(#{quota_hash[:group_warn_ram_quota_exceeded]}}) "      if quota_hash[:group_warn_ram_quota_exceeded]
    quota_message += "(#{quota_hash[:group_warn_storage_quota_exceeded]}}) "  if quota_hash[:group_warn_storage_quota_exceeded]
    quota_message += "(#{quota_hash[:group_warn_vms_quota_exceeded]}}) "      if quota_hash[:group_warn_vms_quota_exceeded]
    quota_message += "(#{quota_hash[:owner_warn_cpu_quota_exceeded]}}) "      if quota_hash[:owner_warn_cpu_quota_exceeded]
    quota_message += "(#{quota_hash[:owner_warn_ram_quota_exceeded]}}) "      if quota_hash[:owner_warn_ram_quota_exceeded]
    quota_message += "(#{quota_hash[:owner_warn_storage_quota_exceeded]}}) "  if quota_hash[:owner_warn_storage_quota_exceeded]
    quota_message += "(#{quota_hash[:owner_warn_vms_quota_exceeded]}}) "      if quota_hash[:owner_warn_vms_quota_exceeded]
    log(:info, "Inspecting quota_message: #{quota_message}")
    @miq_request.set_message(quota_message[0..250])
    @miq_request.set_option(:service_quota_warn_exceeded, quota_message)
    $evm.root['ae_result'] = 'ok'
    $evm.object['reason'] = quota_message
    # send a warning message that quota threshold is close
    $evm.instantiate('/Service/Provisioning/Email/ServiceTemplateProvisionRequest_Warning')
  end

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
