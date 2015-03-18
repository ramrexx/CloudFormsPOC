# service_request_quota_validation.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method validates the group and/or owner quotas using the values
# [max_group_cpu, max_group_memory, max_group_vms, max_owner_cpu, max_owner_memory, max_owner_vms]
# in the following order:
# 1. In the model
# 2. Group tags - This looks at the Group for the following tag values: [quota_max_cpu, quota_max_memory, quota_max_vms]
# 3. Owner tags - This looks at the User for the following tag values: [quota_max_cpu, quota_max_memory, quota_max_vms]
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

  def query_prov_options(parent_service_template, prov_option, options_array=[])
    parent_service_template.service_resources.each do |child_service_resource|
      # skip catalog item if generic
      if parent_service_template.service_type == 'composite'
        next if child_service_resource.resource.prov_type == 'generic'
        child_service_resource.resource.service_resources.each do |grandchild_service_template_service_resource|
          log(:info, "Retrieving #{prov_option}=>#{grandchild_service_template_service_resource.resource.get_option(prov_option)} from Service Catalog Bundle")
          options_array << grandchild_service_template_service_resource.resource.get_option(prov_option)
        end
      else
        next if parent_service_template.prov_type == 'generic'
        log(:info, "Retrieving #{prov_option}=>#{child_service_resource.resource.get_option(prov_option)} from Service Catalog Item")
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
      log(:info, "template_cpu_totals: #{template_cpu_totals.inspect}")
    end
    dialog_cpus_array = []
    options_hash.each do |sequence_id, options|
      dialog_cpus_array << options[:cores_per_socket] unless options[:cores_per_socket].blank?
    end
    unless dialog_cpus_array.blank?
      dialog_cpu_totals = dialog_cpus_array.collect(&:to_i).inject(&:+)
      log(:info, "dialog_cpu_totals: #{dialog_cpu_totals.inspect}") unless dialog_cpu_totals.zero?
    end
    if template_cpu_totals.to_i < dialog_cpu_totals.to_i
      total_cpus_requested = dialog_cpu_totals.to_i
    else
      total_cpus_requested = template_cpu_totals.to_i
    end
    log(:info, "total_cpus_requested: #{total_cpus_requested.inspect}")
    return total_cpus_requested
  end

  # get_total_memory_requested
  def get_total_memory_requested(service_template, options_hash)
    # Add up all of the :vm_memory from the provisioning template(s) and the dialog options
    template_memory_array = query_prov_options(service_template, :vm_memory)
    unless template_memory_array.blank?
      log(:info, "template_memory_array: #{template_memory_array.inspect}")
      template_memory_totals = template_memory_array.collect(&:to_i).inject(&:+)
      log(:info, "template_memory_totals: #{template_memory_totals.inspect}")
    end
    dialog_memory_array = []
    options_hash.each do |sequence_id, options|
      log(:info, "sequence_id: #{sequence_id} options[:vm_memory]: #{options[:vm_memory]}")
      dialog_memory_array << options[:vm_memory] unless options[:vm_memory].blank?
    end
    unless dialog_memory_array.blank?
      dialog_memory_totals = dialog_memory_array.collect(&:to_i).inject(&:+)
      log(:info, "dialog_memory_totals: #{dialog_memory_totals.inspect}") unless dialog_memory_totals.zero?
    end
    if template_memory_totals.to_i < dialog_memory_totals.to_i
      total_memory_requested = dialog_memory_totals.to_i
    else
      total_memory_requested = template_memory_totals.to_i
    end
    log(:info, "total_memory_requested: #{total_memory_requested}")
    return total_memory_requested
  end

  # get_total_vms_requested
  def get_total_vms_requested(service_template, options_hash)
    # Add up all of the :number_of_vms from the provisioning template(s) and the dialog options
    template_vms_array = query_prov_options(service_template, :number_of_vms)
    unless template_vms_array.blank?
      log(:info, "template_vms_array: #{template_vms_array.inspect}")
      template_vms_totals = template_vms_array.collect(&:to_i).inject(&:+)
      log(:info, "template_vms_totals: #{template_vms_totals.inspect}")
    end
    dialog_vms_array = []
    options_hash.each do |sequence_id, options|
      log(:info, "sequence_id: #{sequence_id} options[:number_of_vms]: #{options[:number_of_vms]}")
      dialog_vms_array << options[:number_of_vms] unless options[:number_of_vms].blank?
    end
    unless dialog_vms_array.blank?
      dialog_vms_totals = dialog_vms_array.collect(&:to_i).inject(&:+)
      log(:info, "dialog_vms_totals: #{dialog_vms_totals.inspect}") unless dialog_vms_totals.zero?
    end
    if template_vms_totals.to_i < dialog_vms_totals.to_i
      total_vms_requested = dialog_vms_totals.to_i
    else
      total_vms_requested = template_vms_totals.to_i
    end
    log(:info, "total_vms_requested: #{total_vms_requested}")
    return total_vms_requested
  end

  # check_quotas
  def check_quotas(miq_request, entity, quota_hash)
    unless entity.respond_to?('ldap_group')
      # set group specific values
      entity_name = entity.description
      entity_type = 'Group'
      # set reason variables
      entity_cpu_reason       = :group_cpu_quota_exceeded
      entity_warn_cpu_reason  = :group_warn_cpu_quota_exceeded
      entity_ram_reason       = :group_ram_quota_exceeded
      entity_warn_ram_reason  = :group_warn_ram_quota_exceeded
      entity_vms_reason       = :group_vms_quota_exceeded
      entity_warn_vms_reason  = :group_warn_vms_quota_exceeded
      quota_max_cpu = nil || $evm.object['max_group_cpu'].to_i
      log(:info, "Found quota from model <max_group_cpu> with value #{quota_max_cpu}") unless quota_max_cpu.zero?
      quota_warn_cpu = nil || $evm.object['warn_group_cpu'].to_i
      log(:info, "Found quota from model <warn_group_cpu> with value #{quota_warn_cpu}") unless quota_warn_cpu.zero?
      quota_max_memory = nil || $evm.object['max_group_memory'].to_i
      log(:info, "Found quota from model <max_group_memory> with value: #{quota_max_memory}") unless quota_max_memory.zero?
      quota_warn_memory = nil || $evm.object['warn_group_memory'].to_i
      log(:info, "Found quota from model <warn_group_memory> with value: #{quota_warn_memory}") unless quota_warn_memory.zero?
      quota_max_vms = nil || $evm.object['max_group_vms'].to_i
      log(:info, "Found quota from model <max_group_vms> with value #{quota_max_vms}") unless quota_max_vms.zero?
      quota_warn_vms = nil || $evm.object['warn_group_vms'].to_i
      log(:info, "Found quota from model <warn_group_vms> with value #{quota_warn_vms}") unless quota_warn_vms.zero?
    else
      # set user specific values
      entity_name = entity.name
      entity_type = 'User'
      # set reason variables
      entity_cpu_reason       = :owner_cpu_quota_exceeded
      entity_warn_cpu_reason  = :owner_warn_cpu_quota_exceeded
      entity_ram_reason       = :owner_ram_quota_exceeded
      entity_warn_ram_reason  = :owner_warn_ram_quota_exceeded
      entity_vms_reason       = :owner_vms_quota_exceeded
      entity_warn_vms_reason  = :owner_warn_vms_quota_exceeded
      # Use value from model unless specified
      quota_max_cpu = nil || $evm.object['max_owner_cpu'].to_i
      log(:info, "Found quota from model <max_owner_cpu> with value #{quota_max_cpu}") unless quota_max_cpu.zero?
      quota_warn_cpu = nil || $evm.object['warn_owner_cpu'].to_i
      log(:info, "Found quota from model <warn_owner_cpu> with value #{quota_warn_cpu}") unless quota_warn_cpu.zero?
      quota_max_memory = nil || $evm.object['max_owner_memory'].to_i
      log(:info, "Found quota from model <max_owner_memory> with value: #{quota_max_memory}") unless quota_max_memory.zero?
      quota_warn_memory = nil || $evm.object['warn_owner_memory'].to_i
      log(:info, "Found quota from model <warn_owner_memory> with value: #{quota_warn_memory}") unless quota_warn_memory.zero?
      quota_max_vms = nil || $evm.object['max_owner_vms'].to_i
      log(:info, "Found quota from model <max_owner_vms> with value #{quota_max_vms}") unless quota_max_vms.zero?
      quota_warn_vms = nil || $evm.object['warn_owner_vms'].to_i
      log(:info, "Found quota from model <warn_owner_vms> with value #{quota_warn_vms}") unless quota_warn_vms.zero?
    end

    # Get the current consumption
    (entity_consumption||={})[:cpu]           = entity.allocated_vcpu
    entity_consumption[:memory]               = entity.allocated_memory
    entity_consumption[:vms]                  = entity.vms.select {|vm| vm.id if ! vm.archived }.count
    entity_consumption[:allocated_storage]    = entity.allocated_storage
    entity_consumption[:provisioned_storage]  = entity.provisioned_storage
    log(:info, "#{entity_type}: #{entity_name} current Storage Allocated (bytes): #{entity_consumption[:allocated_storage]}")
    log(:info, "#{entity_type}: #{entity_name} current Storage Provisioned (bytes): #{entity_consumption[:provisioned_storage]}")

    ##########
    # CPU Quota Check
    ##########
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

    ##########
    # Memory Quota Check
    ##########
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

    ##########
    # VMs Quota Check
    ##########
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
  miq_request = $evm.root['miq_request']
  log(:info, "Request id: #{miq_request.id} miq_request.options: #{miq_request.options.inspect}")

  # Get dialog options from miq_request
  dialog_options = miq_request.options[:dialog]
  log(:info, "Inspecting Dialog Options: #{dialog_options.inspect}")
  options_hash = get_options_hash(dialog_options)

  # lookup the service_template object
  service_template = $evm.vmdb(miq_request.source_type, miq_request.source_id)
  log(:info, "service_template id: #{service_template.id} service_type: #{service_template.service_type} description: #{service_template.description} services: #{service_template.service_resources.count}")

  # get the user and group objects
  #user = $evm.root['user']
  user = miq_request.requester
  group = user.current_group

  (quota_hash||={})[:quota_exceeded] = false
  quota_hash[:quota_warn_exceeded] = false
  quota_hash[:total_cpus_requested] = get_total_cpus_requested(service_template, options_hash)
  quota_hash[:total_memory_requested] = get_total_memory_requested(service_template, options_hash)
  quota_hash[:total_vms_requested] = get_total_vms_requested(service_template, options_hash)
  log(:info, "Inspecting quota_hash: #{quota_hash}")

  # exit if no work is needed
  exit MIQ_OK if quota_hash[:total_cpus_requested].zero? && quota_hash[:total_memory_requested].zero? && quota_hash[:total_vms_requested].zero?

  # specify whether quotas should be managed by group or user or both (valid options are [true | false | 'both'])
  manage_quotas_by_group = $evm.object['manage_quotas_by_group'] || true
  if manage_quotas_by_group =~ (/(both|true|t|yes|y|1)$/i)
    check_quotas(miq_request, group, quota_hash)
  end
  if manage_quotas_by_group =~ (/(both|false|f|no|n|0)$/i)
    check_quotas(miq_request, user, quota_hash)
  end

  log(:info, "quota_hash: #{quota_hash.inspect}")
  if quota_hash[:quota_exceeded]
    quota_message = "Service request denied due to the following quota limits:"
    quota_message += "(#{quota_hash[:group_cpu_quota_exceeded]}}) " unless quota_hash[:group_cpu_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:group_ram_quota_exceeded]}}) " unless quota_hash[:group_ram_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:group_vms_quota_exceeded]}}) " unless quota_hash[:group_vms_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:owner_cpu_quota_exceeded]}}) " unless quota_hash[:owner_cpu_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:owner_ram_quota_exceeded]}}) " unless quota_hash[:owner_ram_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:owner_vms_quota_exceeded]}}) " unless quota_hash[:owner_vms_quota_exceeded].blank?
    log(:info, "Inspecting quota_message: #{quota_message}")
    miq_request.set_message(quota_message[0..250])
    miq_request.set_option(:service_quota_exceeded, quota_message)
    $evm.root['ae_result'] = 'error'
    $evm.object['reason'] = quota_message
  elsif quota_hash[:quota_warn_exceeded]
    quota_message = "Service request warning due to the following quota limits:"
    quota_message += "(#{quota_hash[:group_warn_cpu_quota_exceeded]}}) " unless quota_hash[:group_warn_cpu_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:group_warn_ram_quota_exceeded]}}) " unless quota_hash[:group_warn_ram_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:group_warn_vms_quota_exceeded]}}) " unless quota_hash[:group_warn_vms_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:owner_warn_cpu_quota_exceeded]}}) " unless quota_hash[:owner_warn_cpu_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:owner_warn_ram_quota_exceeded]}}) " unless quota_hash[:owner_warn_ram_quota_exceeded].blank?
    quota_message += "(#{quota_hash[:owner_warn_vms_quota_exceeded]}}) " unless quota_hash[:owner_warn_vms_quota_exceeded].blank?
    log(:info, "Inspecting quota_message: #{quota_message}")
    miq_request.set_message(quota_message[0..250])
    miq_request.set_option(:service_quota_warn_exceeded, quota_message)
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
