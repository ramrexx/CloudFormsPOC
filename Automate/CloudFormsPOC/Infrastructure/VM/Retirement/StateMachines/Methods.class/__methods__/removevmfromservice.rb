# RemoveVMFromService.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method removes the VM from the service during retirement and for Flex VMs subtract parent vm tag :flex_current by 1
#

# process_tags - create categories and tags
def process_tags(category, single_value, tag)
  # Convert to lower case and replace all non-word characters with underscores
  category_name = category.to_s.downcase.gsub(/\W/, '_')
  tag_name = tag.to_s.downcase.gsub(/\W/, '_')
  # if the category exists else create it
  unless $evm.execute('category_exists?', category_name)
    $evm.log(:info, "Category #{category_name} doesn't exist, creating category")
    $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category}")
  end
  # if the tag exists else create it
  unless $evm.execute('tag_exists?', category_name, tag_name)
    $evm.log(:info, "Adding new tag #{tag_name} in Category #{category_name}")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag}")
  end
end

case $evm.root['vmdb_object_type']

when 'vm'
  # Get vm object from the VM class versus the VmOrTemplate class for vm.remove_from_service to work
  vm = $evm.vmdb("vm", $evm.root['vm_id'])

  # Get parent_service from vm
  parent_service = vm.service
  raise "$evm.root['vm'].service not found" if parent_service.nil?
  $evm.log(:info, "Service: #{parent_service.name} id: #{parent_service.id} vms: #{parent_service.vms.count} tags: #{parent_service.tags.inspect}")

  # Remove vm from parent service
  $evm.log(:info, "Removing VM: #{vm.name} from Service: #{parent_service.name}")
  vm.remove_from_service

  unless vm.custom_get(:flex_vm_guid).to_s.blank?
    parent_vm = $evm.vmdb('vm').find_by_guid(vm.custom_get(:flex_vm_guid).to_s)
    $evm.log(:info, "Found flex parent_vm: #{parent_vm.name}")
    unless parent_vm.nil?
      # Get the flex_current tag and convert it to an integer
      flex_current = parent_vm.tags(:flex_current).first.to_i
      # Ensure that flex_current is not 0
      unless flex_current.zero?
        # Decrease flex_current by 1
        new_serviceflex_current = flex_current - 1
        # Tag parent vm with new_serviceflex_current
        unless parent_vm.tagged_with?('flex_current',new_serviceflex_current)
          process_tags('flex_current', true, new_serviceflex_current)
          $evm.log(:info, "Assinging tag: {#{:flex_current} => #{new_serviceflex_current}} to VM: #{parent_vm.name}")
          parent_vm.tag_assign("flex_current/#{new_serviceflex_current}")
        end
      end
    end # unless parent_vm.nil?
  end # unless vm.custom_get(:flex_vm_guid).to_s.blank?
end # case $evm.root['vmdb_object_type']
