# sync_vm_tags.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: Synchronize tags between a CFME VM and a corresponding EC2 instance
#

def log_and_update_message(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  @task.message = msg if @task && (update_message || level == 'error')
end

def retry_method(retry_time, msg)
  log_and_update_message(:info, "#{msg} - Waiting #{retry_time} seconds}", true)
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

def get_aws_object(provider, type='EC2')
  require 'aws-sdk'
  AWS.config( :access_key_id => provider.authentication_userid, :secret_access_key => provider.authentication_password, :region => provider.provider_region )
  return Object::const_get("AWS").const_get(type).new()
end

def process_tags( category, category_description, single_value, tag, tag_description)
  # Convert to lower case and replace all non-word characters with underscores
  category_name = category.to_s.downcase.gsub(/\W/, '_')
  tag_name = tag.to_s.downcase.gsub(/\W/, '_')
  unless $evm.execute('category_exists?', category_name)
    log_and_update_message(:info, "Creating Category {#{category_name} => #{category_description}}")
    $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category_description}")
  end
  unless $evm.execute('tag_exists?', category_name, tag_name)
    log_and_update_message(:info, "Creating Tag {#{tag_name} => #{tag_description}} in Category #{category_name}")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag_description}")
  end
  return category_name, tag_name
end

case $evm.root['vmdb_object_type']
when 'miq_provision'
  prov = $evm.root["miq_provision"]
  log_and_update_message(:info, "Provision: #{prov.id} Request: #{prov.miq_provision_request.id} Type: #{prov.type}")
  vm = prov.vm
  retry_method(15.seconds, "Provisioned instance: #{prov.get_option(:vm_target_name)} not ready") if vm.nil?
when 'vm'
  vm = $evm.root['vm']
end
exit MIQ_OK unless (vm.vendor.downcase rescue nil) == 'amazon'

ec2 = get_aws_object(vm.ext_management_system, 'EC2')
raise "Unable to get EC2 Connection" if ec2.nil?

ec2_instance = ec2.instances[vm.ems_ref]
log_and_update_message(:info, "VM: #{vm.name} EC2: #{ec2_instance.id}")

ec2_instance.tags.each do |key, value|
  #next if key.starts_with?("cfme_")
  next if key.downcase == "name"
  category_name, tag_name = process_tags(key, "EC2 Tag #{key}", true, value, value)
  unless vm.tagged_with?(category_name,tag_name)
    log_and_update_message(:info, "Assigning Tag: {#{category_name} => #{tag_name}} to VM: #{vm.name}")
    vm.tag_assign("#{category_name}/#{tag_name}")
  end
end

vm.tags.each do |tag_element|
  #next if tag_element.starts_with?("folder_path")
  tag = tag_element.split("/", 2)
  log_and_update_message(:info, "Assigning Tag: {#{tag.first} => #{tag.last}} to EC2 Instance: #{vm.ems_ref}", true)
  ec2_instance.add_tag("#{tag.first}", :value => tag.last.to_s)
end
