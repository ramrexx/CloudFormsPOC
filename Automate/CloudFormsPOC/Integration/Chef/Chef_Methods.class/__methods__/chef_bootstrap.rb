###################################
#
# CFME Automate Method: Chef_Bootstrap
#
# Notes: This method uses knife to bootstrap a Chef client
#
###################################
begin
  # Method for logging
  def log(level, message)
    $evm.log(level, "#{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def dump_vm(vm)
    log(:info, "VM:<#{vm.name}> Begin Attributes [vm.attributes]")
    vm.attributes.sort.each { |k, v| log(:info, "VM:<#{vm.name}> Attributes - #{k}: #{v.inspect}")}
    log(:info, "VM:<#{vm.name}> End Attributes [vm.attributes]")
    log(:info, "Full Dump: #{vm.inspect}")
    log(:info, "")
  end
  
  # basic retry logic
  def retry_method(retry_time=1.minute)
    log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

      # process_tags - Dynamically create categories and tags
  def process_tags( category, category_description, single_value, tag, tag_description )
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.to_s.downcase.gsub(/\W/, '_')
    tag_name = tag.to_s.downcase.gsub(/\W/, '_')
    tag_name = tag.gsub(/:/, '_')
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

  def run_linux_admin(cmd, timeout=10)
    require 'linux_admin'
    require 'timeout'
    begin
      Timeout::timeout(timeout) {
        log(:info, "Executing #{cmd} with timeout of #{timeout} seconds")
        result = LinuxAdmin.run(cmd)
        log(:info, "Inspecting output: #{result.output.inspect}")
        log(:info, "Inspecting error: #{result.error.inspect}") unless result.error.blank? 
        log(:info, "Inspecting exit_status: #{result.exit_status.inspect}")
        return result
      }
    rescue => timeout
      log(:error, "Error executing chef: #{timeout.class} #{timeout} #{timeout.backtrace.join("\n")}")
      return false
    end
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  vm = nil
  chef_role = nil
  chef_recipe = nil
  chef_environment = nil

  case $evm.root['vmdb_object_type']
  when 'miq_provision'
    prov = $evm.root['miq_provision']
    chef_role = prov.get_tags[:chef_role]
    chef_recipe = prov.get_tags[:chef_recipe]
    chef_environment = prov.get_tags[:chef_environment]
    log(:info, "CHEF Tags from Prov: #{chef_role rescue 'nil'} - #{chef_recipe rescue 'nil'} #{chef_environment rescue 'nil'}")
    vm = prov.vm
  when 'vm'
    chef_role = $evm.root['dialog_chef_role']
    chef_recipe = $evm.root['dialog_chef_recipe']
    chef_environment = $evm.root['dialog_chef_environment']
    log(:info, "CHEF Dialog Info: #{chef_role rescue 'nil'} - #{chef_recipe rescue 'nil'} #{chef_environment rescue 'nil'}")
    vm = $evm.root['vm']
  end

  dump_vm(vm)

  unless chef_role || chef_recipe
    log(:info, "nothing to do for chef, bye")
    exit MIQ_OK
  end

  if vm.nil?
    log(:error, "VM is nil, cannot continue")
    raise "VM is nil, cannot continue with method"
  end

  log(:info, "Requested role:'#{chef_role rescue 'nil'}")
  log(:info, "Requested recipe:'#{chef_recipe rescue 'nil'}")

  log(:info, "VM IP Addresses: #{vm.ipaddresses.inspect}")

  # Since this may support provisioning we need to put in retry logic to wait 
  # until IP Addresses are populated.
  unless vm.ipaddresses.empty?
    non_zeroconf = false
    vm.ipaddresses.each do |ipaddr|
      non_zeroconf = true unless ipaddr.match(/^(169.254|0)/)
      log(:info, "VM:<#{vm.name}> IP Address found #{ipaddr} (#{non_zeroconf})")
    end
    if non_zeroconf
      log(:info, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> present.")
      $evm.root['ae_result'] = 'ok'
    else
      log(:warn, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> not present.")
      retry_method("15.seconds")
    end
  else
    log(:warn, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> not present.")
    retry_method("15.seconds")
  end

  if vm.hostnames.empty? || vm.hostnames.first.blank?
    log(:info, "Waiting for vm hostname to populate")
    vm.refresh
    retry_method("15.seconds")
  end

  username = $evm.object['username']
  password = $evm.object.decrypt('password')

  if chef_environment.blank?
    chef_environment = $evm.object['chef_environment']
    chef_environment = "_default" if chef_environment.blank?
    log(:info, "Defaulted chef_environment to #{chef_environment}")
  end
  
  # VM Has not yet been bootstrapped in chef
  if vm.custom_get("CHEF_Bootstrapped").blank?
    cmd = "/usr/bin/knife bootstrap #{vm.ipaddresses.first} -x '#{username}' -P '#{password}' -E #{chef_environment} --node-ssl-verify-mode none"
    result = run_linux_admin(cmd, 300)
    if result
      log(:info, "Successfully bootstrapped #{vm.name}: #{result}")
      vm.custom_set("CHEF_Bootstrapped", "YES: #{Time.now}}")
      vm.custom_set("CHEF_Failure", nil)
      process_tags("chef_bootstrapped", "Chef Bootstrapped", true, "true", "True")
      vm.tag_assign("chef_bootstrapped/true")
    else
      log(:error, "Unable to bootstrap #{vm.name}, please check CHEF stacktrace")
      vm.custom_set("CHEF_Failure", "Bootstrap: #{Time.now}")
      process_tags("chef_bootstrapped", "Chef Bootstrapped", true, "false", "False")
      vm.tag_assign("chef_bootstrapped/false")
      raise "Exiting due to chef bootstrap failure"
    end
  end

  vmname = vm.hostnames.first
  log(:info, "Presuming chef name is #{vmname}")

  unless chef_role.blank?
    cmd = "/usr/bin/knife node run_list add #{vmname} role[#{chef_role}] -E #{chef_environment}"
    result = run_linux_admin(cmd)
    log(:info, "Chef role add command returned #{result}")
    if result
      log(:info, "Role #{chef_role} added successfully")
    else
      log(:error, "Role #{chef_role}, failed to add.  Please check VM for logs")
    end
  end

  unless chef_recipe.blank?
    cmd = "/usr/bin/knife node run_list add #{vmname} recipe[#{chef_recipe}] -E #{chef_environment}"
    result = run_linux_admin(cmd)
    log(:info, "Chef recipe add command returned #{result}")
    if result
      log(:info, "Recipe #{chef_recipe} added successfully")
    else
      log(:error, "Recipe #{chef_recipe}, failed to add.  Please check VM for logs")
    end
  end

  vm.custom_set("CHEF_Environment", chef_environment)
  require 'yaml'
  cmd = "/usr/bin/knife node show #{vmname} -r -l"
  result = run_linux_admin(cmd)
  yaml = result.output.strip
  run_list = YAML.load(yaml)["#{vmname}"]["run_list"]
  log(:debug, "CHEF_Run_List for Node #{vmname}: #{run_list}")
  vm.custom_set("CHEF_Run_List", run_list)
  run_list.gsub! ",", ""
  run_list.split(" ").each { |run_list_item|
      log(:info, "run_list_item: #{run_list_item}")
      result = run_list_item.match(/^(role|recipe)\[(.*?)\]$/)
      log(:info, "Matched #{result}")
      if result[1] && result[2]
        process_tags("chef_#{result[1]}", "Chef #{result[1]}", false, result[2], result[2])
        vm.tag_assign("chef_#{result[1]}/#{result[2].gsub! ':', '_'}")
      end
  }

  vm.custom_set("CHEF_Node_Name", vmname)
 
  log(:debug, "Automate Method Ended")
  exit MIQ_OK

# Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_OK
end
