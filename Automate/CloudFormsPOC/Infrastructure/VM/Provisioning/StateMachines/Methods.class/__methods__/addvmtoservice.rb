#
# Description: This method adds VMs and Flexed VMs to a service after Post Provisioning
#

def log(level, msg, update_message=false)
  $evm.log(level, "#{@method} - #{msg}")
  $evm.root['miq_provision'].message = "#{msg}" if $evm.root['miq_provision'] && update_message
end

def process_tags(category, single_value, tag)
  # Convert to lower case and replace all non-word characters with underscores
  category_name = category.to_s.downcase.gsub(/\W/,'_')
  tag_name = tag.to_s.downcase.gsub(/\W/,'_')

  # if the category exists else create it
  unless $evm.execute('category_exists?', category_name)
    log(:info, "Category <#{category_name}> doesn't exist, creating category")
    $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category}")
  end
  # if the tag exists else create it
  unless $evm.execute('tag_exists?', category_name, tag_name)
    log(:info, "Adding new tag <#{tag_name}> in Category <#{category_name}>")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag}")
  end
end

# Get miq_provision from root
prov = $evm.root['miq_provision']
raise "miq_provision object not found" if prov.nil?
log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

vm = prov.vm
raise "$evm.root['miq_provision'].vm not found" if prov.vm.nil?

prov_tags = prov.get_tags
log(:info, "Inspecting miq_provision tags:<#{prov_tags.inspect}>")

# skip this method if a :service_guid and :service_resource_id exist because the instance will automatically be added to the service anyway
service_guid = prov.options.fetch(:service_guid, nil)
service_resource_id = prov.options.fetch(:service_resource_id, nil)
if service_guid.nil? && service_resource_id.nil?
  flex = false
  if prov.options.has_key?(:ws_values)
    ws_values = prov.options[:ws_values]
    unless ws_values[:service_id].blank?
      # get :service_id from ws_values (This is set during the Build_VMProvisionRequest)
      service_id = ws_values.fetch(:service_id, nil)
      log(:info, "Found ws_values[:service_id]: #{service_id.inspect}") unless service_id.nil?
    end
    unless ws_values[:flex_reason].blank?
      flex = true
    end
  end

  unless service_id.nil?
    # Look up the parent service by id
    parent_service = $evm.vmdb('service').find_by_id(service_id)
    raise "service_id: #{service_id} not found" if parent_service.nil?
    log(:info, "Service: #{parent_service.name} id: #{parent_service.id} guid: #{parent_service.guid} vms: #{parent_service.vms.count} tags:<#{parent_service.tags.inspect}")

    # Add vm to the parent service
    log(:info, "Adding VM: #{vm.name} to Service: #{parent_service.name}", true)
    vm.add_to_service(parent_service)
    log(:info, "Service: #{parent_service.name} vms: #{parent_service.vms.count} tags: #{parent_service.tags.inspect}")

    # Process Flexed VM
    if flex
      parent_vm = $evm.vmdb('vm').find_by_guid(ws_values[:flex_vm_guid])
      log(:info, "Found flex parent_vm: #{parent_vm.name}")

      # Add custom attributes on the provisioned VM
      log(:info, "Adding custom attribute {:flex_reason => #{ws_values[:flex_reason].to_s}} to VM: #{vm.name}", true)
      vm.custom_set(:flex_reason, ws_values[:flex_reason].to_s)
      log(:info, "Adding custom attribute {:flex_vm_name => #{ws_values[:flex_vm_name].to_s}} to VM: #{vm.name}", true)
      vm.custom_set(:flex_vm_name, ws_values[:flex_vm_name].to_s)
      log(:info, "Adding custom attribute {:flex_vm_guid => #{ws_values[:flex_vm_guid].to_s}} to VM: #{vm.name}", true)
      vm.custom_set(:flex_vm_guid, ws_values[:flex_vm_guid].to_s)

      # Get the flex_current tag and convert it to an integer
      flex_current = parent_vm.tags(:flex_current).first.to_i
      # Get the flex_pending tag and convert it to an integer
      flex_pending = parent_vm.tags(:flex_pending).first.to_i

      # Never drop below 0
      unless flex_pending.zero?
        # Decrement flex_pending by 1
        new_flex_pending = flex_pending - 1
        # Tag parent service with new_flex_pending
        unless parent_vm.tagged_with?('flex_pending', new_flex_pending)
          # Create flex_pending tags if they do not already exist
          process_tags('flex_pending', true, new_flex_pending)
          log(:info, "Assigning tag: {#{flex_pending} => #{new_flex_pending}} to parent_vm: #{parent_vm.name}", true)
          parent_vm.tag_assign("flex_pending/#{new_flex_pending}")
        end
      end

      # Increment flex_current by 1
      new_flex_current = flex_current + 1
      # Tag parent service with new_flex_current
      unless parent_vm.tagged_with?('flex_current', new_flex_current)
        # Create flex_current tags if they do not already exist
        process_tags('flex_current', true, new_flex_current)
        log(:info, "Assigning tag: {:flex_current => #{new_flex_current}} to parent_vm: #{parent_vm.name}", true)
        parent_vm.tag_assign("flex_current/#{new_flex_current}")
      end
    end # if flex
  end # if service_guid.nil? && service_resource_id.nil?
end # service_id.nil?
