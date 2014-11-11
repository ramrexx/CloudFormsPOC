# post_createInstance.rb
#
# Description: Perform tasks after instance has been deployed
#

def log(level, msg, update_message=false)
  $evm.log(level,"#{msg}")
  $evm.root['service_template_provision_task'].message = msg if $evm.root['service_template_provision_task'] && update_message
end

# Look for service dialog variables in the dialog options hash that start with "dialog_tag_[0-9]",
def get_dialog_tags_hash(dialog_options)
  log(:info, "Processing get_dialog_tags_hash...", true)
  dialogs_tags_hash = {}

  dialog_tags_regex = /^dialog_tag_(.*)/
  # Loop through all of the tags and build a dialogs_tags_hash
  dialog_options.each do |k, v|
    next if v.blank?
    if dialog_tags_regex =~ k
      tag_category = $1
      tag_value = v.downcase
      unless tag_value.blank?
        log(:info, "Adding tag: {#{tag_category.inspect} => #{tag_value.inspect}} to dialogs_tags_hash")
        (dialogs_tags_hash ||={})[tag_category] = tag_value
      end
    end
  end
  log(:info, "Inspecting dialogs_tags_hash: #{dialogs_tags_hash.inspect}")
  log(:info, "Processing get_dialog_tags_hash...Complete", true)
  return dialogs_tags_hash
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

# vm_tagging - tag the vm
def vm_tagging(vm, dialogs_tags_hash)
  log(:info, "Processing vm_tagging...", true)
  unless dialogs_tags_hash.nil?
    dialogs_tags_hash.each do |k,v|
      log(:info, "Adding Tag: {#{k.inspect} => #{v.inspect}} to VM: #{vm.name}")
      process_tags( k, true, v )
      vm.tag_assign("#{k}/#{v}")
    end
  end
  log(:info, "Processing vm_tagging...Complete", true)
end

$evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

service_template_provision_task = $evm.root['service_template_provision_task']
service = service_template_provision_task.destination
log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")

vm_guid = service_template_provision_task.get_option(:vm_guid)

vm = $evm.vmdb('vm').find_by_guid(vm_guid)
raise "VM not found" if vm.nil?

log(:info, "Found VM: #{vm.name}", true)

user = $evm.vmdb('user').find_by_id($evm.root['user_id'])
group = user.current_group

vm.owner = user
vm.group = group

log(:info, "VM: #{vm.name} Owner: #{vm.owner.name} Group: #{vm.owner.current_group.description}")

# build a hash of dialog_options
dialog_options        = $evm.root['service_template_provision_task'].dialog_options
log(:info, "dialog_options: #{dialog_options.inspect}")
dialogs_tags_hash     = get_dialog_tags_hash(dialog_options)

vm_tagging(vm, dialogs_tags_hash)

# Add vm to the service
log(:info, "Adding VM: #{vm.name} to Service: #{service.name}", true)
vm.add_to_service(service)
log(:info, "Service: #{service.name} vms: #{service.vms.count}")

# unless service.nil?
#   log(:info, "Removing Service: #{service.name} Id: #{service.id} from CFME database", true)
#   service.remove_from_vmdb
# end
