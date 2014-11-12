# addawstags.rb
#
# Description: Look for instance tags in EC2 and tag CFME VM
#

begin

  def log(msg)
    log(:info, msg, false)
  end

  def log(level, message, update_message=false)
    $evm.log(level, "#{@method} - #{message}")
    if update_message
      case $evm.root['vmdb_object_type']
      when 'miq_provision'
        $evm.root['miq_provision'].message = "#{@method} - #{msg}"
      when 'service_template_provision_task'
        $evm.root['service_template_provision_task'] = "#{@method} - #{msg}" if $evm.root['service_template_provision_task']
      end
    end
  end

  def log_err(err, update_message=false, update_reason=false)
    log(:error, "#{err.class} [#{err}]", update_message)
    log(:error, "#{err.backtrace.join("\n")}")
    if update_reason
       $evm.root['ae_result'] = 'error'
       $evm.root['ae_reason'] = "#{err.class} [#{err}]"
    end
  end

  def get_aws_object(ext_mgt_system, type="EC2")
    require 'aws-sdk'
    AWS.config(
      :access_key_id => ext_mgt_system.authentication_userid,
      :secret_access_key => ext_mgt_system.authentication_password,
      :region => ext_mgt_system.provider_region
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

  log(:info, "Begin Automate Method")

  require 'aws-sdk'

  vm = $evm.root['vm']
  raise "VM is not in $evm.root" if vm.nil?

  ec2 = get_aws_object(vm.ext_management_system)
  raise "Unable to get EC2 Connection" if ec2.nil?

  log(:info, "Got EC2 Object: #{ec2.class} #{ec2.inspect}")

  ec2_instance = ec2.instances[vm.ems_ref.to_s]
  log(:info, "Got EC2 Instance: #{ec2_instance}")

  ec2_instance.tags.each { |key, value|
    next if key.starts_with?("cfme_")
    next if key.downcase == "name"
    process_tags("ec2_#{key}", "EC2 Tag #{key}", true, "#{value}", "#{value}")
    category = "ec2_#{key}".downcase.gsub(/\W/, '_')
    tag_value = value.downcase.gsub(/\W/, '_')
    vm.tag_assign("#{category}/#{tag_value}")
  }

rescue => err
  log_err(err, true, true)
  exit MIQ_ABORT
end
