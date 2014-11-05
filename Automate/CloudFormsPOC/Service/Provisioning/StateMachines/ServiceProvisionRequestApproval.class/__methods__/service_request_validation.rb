#
# service_request_validation.rb
#
# Description: This method validates the service provision request using the values [max_vms, max_cpus, max_memory] from values in the model
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
        #$evm.log(:info, "Inspecting grandchild_service_template_service_resource.resource: #{grandchild_service_template_service_resource.resource.inspect}\n")
        #$evm.log(:info, "Retrieving #{prov_option}=>#{grandchild_service_template_service_resource.resource.get_option(prov_option)}")
        options_array << grandchild_service_template_service_resource.resource.get_option(prov_option)
      end
    else
      next if parent_service_template.prov_type == 'generic'
      $evm.log(:info, "Detected Service Catalog Item")
      #$evm.log(:info, "Inspecting child_service_resource.resource: #{child_service_resource.resource.inspect}\n")
      #$evm.log(:info, "Retrieving #{prov_option}=>#{child_service_resource.resource.get_option(prov_option)}")
      options_array << child_service_resource.resource.get_option(prov_option)
    end

  end # parent_service_template_service_resources.each
  return options_array
end

# max_cpu_check
def max_cpu_check(service_template, options_hash, reason_hash)
  # Add up all of the :cores_per_socket from the template(s) and the dialog options
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
    $evm.log(:info, "dialog_cpu_totals: #{dialog_cpu_totals.inspect} ") unless dialog_cpu_totals.zero?
  else
    dialog_cpu_totals = 0
  end

  if template_cpu_totals.to_i < dialog_cpu_totals.to_i
    total_cpus_requested = dialog_cpu_totals.to_i
  else
    total_cpus_requested = template_cpu_totals.to_i
  end
  $evm.log(:info, "total_cpus_requested: #{total_cpus_requested.inspect} ")

  # Use value from model unless specified above
  model_max_cpus = nil || $evm.object['max_cpus'].to_i
  # Validate model_max_cpus if not nil or empty
  unless model_max_cpus.zero?
    $evm.log(:info,"Auto-Approval Threshold(Model): model_max_cpus=#{model_max_cpus} detected")
    if total_cpus_requested && (total_cpus_requested > model_max_cpus)
      $evm.log(:warn, "Auto-Approval Threshold: Amount of vCPUs requested: #{total_cpus_requested} exceeds: #{model_max_cpus}")
      reason_hash[:reason1] = "Requested CPUs #{total_cpus_requested} limit is #{model_max_cpus}"
    end
  end
end

# max_memory_check
def max_memory_check(service_template, options_hash, reason_hash)
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

  model_max_memory = nil || $evm.object['max_memory'].to_i
  # Validate model_max_memory if not 0
  unless model_max_memory.zero?
    $evm.log(:info,"Auto-Approval Threshold(Model): model_max_memory=#{model_max_memory} detected")
    if total_memory_requested && (total_memory_requested > model_max_memory)
      $evm.log(:warn, "Auto-Approval Threshold: Amount of vRAM requested: #{total_memory_requested} exceeds: #{model_max_memory}")
      reason_hash[:reason2] = "Requested Memory #{total_memory_requested}MB limit is #{model_max_memory}MB"
    end
  end
end

# set thresholds based on dialog_option_?_flavor
def max_flavor_check(service_template, options_hash, reason_hash)
  reject = false
  # flavor_weight = {'xsmall' => 1, 'small' => 2, 'medium' => 3, 'large' => 4, 'xlarge' => 5, 'xxlarge' => 6}
  options_hash.each do |sequence_id, options|
    next if options[:flavor].blank? || reject
    $evm.log(:info, "sequence_id: #{sequence_id} options[:flavor]: #{options[:flavor] rescue nil}")
    case options[:flavor]
    when 'xsmall'
      #reject = true
    when 'small'
      #reject = true
    when 'medium'
      #reject = true
    when 'large'
      #reject = true
    when 'xlarge'
      #reject = true
    when 'xxlarge'
      #reject = true
    end
    reason_hash[:reason3] = "Requested flavor #{options[:flavor]} require manual approval" if reject
  end
end

$evm.log(:info, "CFME Automate Method Started")

# dump all root attributes to the log
#dump_root()

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

reason_hash = {}

max_memory_check(service_template, options_hash, reason_hash)

max_cpu_check(service_template, options_hash, reason_hash)

max_flavor_check(service_template, options_hash, reason_hash)

# if approval required then send request into a pending state
$evm.log(:info, "reason_hash: #{reason_hash.inspect}")
unless reason_hash.blank?
  msg =  "Service Request was not auto-approved for the following reason(s): "
  msg += "(#{reason_hash[:reason1]}) " unless reason_hash[:reason1].blank?
  msg += "(#{reason_hash[:reason2]}) " unless reason_hash[:reason2].blank?
  msg += "(#{reason_hash[:reason3]}) " unless reason_hash[:reason3].blank?
  miq_request.set_message(msg)
  $evm.root['ae_result'] = 'error'
  $evm.object['reason'] = msg
end
