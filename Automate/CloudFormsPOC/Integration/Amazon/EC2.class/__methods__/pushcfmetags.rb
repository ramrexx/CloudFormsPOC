# PushCFMETags.rb
#
# Description: Push CFME VM tags to corresponding EC2 instance
#
require 'aws-sdk'

def log(level, msg, update_message=false)
  $evm.log(level, "#{msg}")
  $evm.root['miq_provision'].message = "#{msg}" if $evm.root['miq_provision'] && update_message
end

def retry_method(retry_time, msg)
  log(:info, "#{msg} - Waiting #{retry_time} seconds}", true)
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

def get_aws_object(provider, type="EC2")
  require 'aws-sdk'
  AWS.config(
    :access_key_id => provider.authentication_userid,
    :secret_access_key => provider.authentication_password,
    :region => provider.provider_region
  )
  return Object::const_get("AWS").const_get(type).new()
end

# process_tags - Dynamically create categories and tags
def process_tags( category, category_description, single_value, tag, tag_description )
  # Convert to lower case and replace all non-word characters with underscores
  category_name = category.to_s.downcase.gsub(/\W/, '_')
  tag_name = tag.to_s.downcase.gsub(/\W/, '_')
  log(:info, "Converted category name:<#{category_name}> Converted tag name: <#{tag_name}>")
  # if the category exists else create it
  unless $evm.execute('category_exists?', category_name)
    log(:info, "Category <#{category_name}> doesn't exist, creating category")
    $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category_description}")
  end
  # if the tag exists else create it
  unless $evm.execute('tag_exists?', category_name, tag_name)
    log(:info, "Adding new tag <#{tag_name}> description <#{tag_description}> in Category <#{category_name}>")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag_description}")
  end
end

case $evm.root['vmdb_object_type']
when 'miq_provision'
  # Get provisioning object
  prov = $evm.root["miq_provision"]
  log(:info, "Provision: #{prov.id} Request: #{prov.miq_provision_request.id} Type: #{prov.type}")
  vm = prov.vm
  retry_method(15.seconds, "Provisioned instance: #{prov.get_option(:vm_target_name)} not ready") if vm.nil?
when 'vm'
  vm = $evm.root['vm']
end
exit MIQ_OK unless (vm.vendor.downcase rescue nil) == 'amazon'

ec2 = get_aws_object(vm.ext_management_system)
raise "Unable to get EC2 Connection" if ec2.nil?

log(:info, "Got EC2 Object: #{ec2.class} #{ec2.inspect}")

ec2_instance = ec2.instances[vm.ems_ref.to_s]
log(:info, "Got EC2 Instance: #{ec2_instance.id}")
log(:info, "Inspecting EC2 Instance: #{ec2_instance.id}")

vm.tags.each { |tag_element|
  next if tag_element.starts_with?("folder_path")
  tag = tag_element.split("/", 2)
  log(:info, "Pushing CFME Tag: #{tag.first} => #{tag.last} to EC2 Instance: ", true)
  ec2_instance.add_tag("#{tag.first}", :value => tag.last.to_s)
}

log(:info, "EC2 Tags Now")
ec2_instance.tags.each {|key, value| log(:info, "\t EC2 Tag: #{key} => #{value}") }
