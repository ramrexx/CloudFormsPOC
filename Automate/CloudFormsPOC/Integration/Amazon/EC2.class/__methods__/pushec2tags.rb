# PushEC2Tags.rb
#
# Description: Push EC2 instance tags to corresponding CFME VM
#
require 'aws-sdk'

def log(level, msg, update_message=false)
  $evm.log(level, "#{msg}")
  $evm.root['miq_provision'].message = "#{msg}" if $evm.root['miq_provision'] && update_message
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

# process_tags - Dynamically create categories, tags
def process_tags( category, category_description, single_value, tag, tag_description, vm )
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

  return if vm.nil?
  if vm.tagged_with?(category_name,tag_name)
    log("info", "VM already tagged with #{tag_name} in Category #{category_name}")
  else
    log("info", "Tagging VM with new #{tag_name} tag in Category #{category_name}")
    vm.tag_assign("#{category_name}/#{tag_name}")
  end
end

vm = $evm.root['vm']
exit MIQ_OK unless (vm.vendor.downcase rescue nil) == 'amazon'

ec2 = get_aws_object(vm.ext_management_system)
raise "Unable to get EC2 Connection" if ec2.nil?

log(:info, "Got EC2 Object: #{ec2.class} #{ec2.inspect}")

ec2_instance = ec2.instances[vm.ems_ref.to_s]
log(:info, "Got EC2 Instance: #{ec2_instance.id}")
log(:info, "Inspecting EC2 Instance: #{ec2_instance.id}")

ec2_instance.tags.each { |key, value|
  #next if key.starts_with?("cfme_")
  next if key.downcase == "name"
  process_tags(key, "EC2 Tag #{key}", true, value, value, vm)
}
