# add_vm_to_service.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method adds VMs and Flexed VMs to a service after Post Provisioning as well as set VM group ownership
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level,"#{msg}")
    @task.message = msg if @task.respond_to?('message') && update_message
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  # basic retry logic
  def retry_method(retry_time, msg='INFO')
    log(:info, "#{msg} - Waiting #{retry_time} seconds}", true)
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
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

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # Get miq_provision from root
  @task = $evm.root['miq_provision']
  log(:info, "Provision:<#{@task.id}> Request:<#{@task.miq_provision_request.id}> Type:<#{@task.type}>")

  vm = @task.vm
  retry_method(15.seconds, "Waiting for VM: #{@task.get_option(:vm_target_name)}") if vm.nil?

  ws_values = @task.options.fetch(:ws_values, {})
  log(:info, "WS Values: #{ws_values.inspect}")

  prov_tags = @task.get_tags
  log(:info, "Inspecting miq_provision tags: #{prov_tags.inspect}")

  # skip this method if a :service_guid and :service_resource_id exist because the instance will automatically be added to the service anyway
  service_guid = @task.get_option(:service_guid)
  service_resource_id = @task.get_option(:service_resource_id)
  if service_guid.nil? && service_resource_id.nil?
    unless ws_values[:service_id].blank?
      # get :service_id from ws_values (This is set during the Build_VMProvisionRequest)
      service_id = ws_values[:service_id]
      log(:info, "Found ws_values[:service_id]: #{service_id.inspect}") unless service_id.nil?
    end

    unless service_id.nil?
      # Look up the parent service by id
      parent_service = $evm.vmdb('service').find_by_id(service_id)
      unless parent_service.nil?
        # Add vm to the parent service
        log(:info, "Adding VM: #{vm.name} to Service: #{parent_service.name}", true)
        vm.add_to_service(parent_service)
        log(:info, "Service: #{parent_service.name} vms: #{parent_service.vms.count} tags: #{parent_service.tags.inspect}")
      end
    end # if service_guid.nil? && service_resource_id.nil?
  end # service_id.nil?

  # get :group_id from @task.options or ws_values (This is set during the Build_VMProvisionRequest)
  group_id = @task.get_option(:group_id) || ws_values[:group_id]
  unless group_id.nil?
    log(:info, "Found group_id: #{group_id.inspect}") unless group_id.nil?
    # Look up the group by id
    group = $evm.vmdb(:miq_group).find_by_id(group_id)
    unless group.nil?
      log(:info, "Assigning ownership for group: #{group.description} to VM: #{vm.name}", true)
      vm.group = group
    end
  end

  # Process Flexed VM
  if ws_values[:flex_reason]
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
  end # if ws_values[:flex_reason]

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "#{err.class} #{err}")
  log(:error, "#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
