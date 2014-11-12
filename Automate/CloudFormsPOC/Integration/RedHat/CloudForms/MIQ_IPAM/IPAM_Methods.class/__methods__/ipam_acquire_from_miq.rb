###################################
#
# EVM Automate Method: IPAM_Acquire_from_MIQ
#
# Notes: EVM Automate method to acquire IP Address information from EVM Automate Model
#
###################################
begin
  @method = 'IPAM_Acquire_from_MIQ'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true


  ############################
  #
  # Method: instance_find
  # Notes: Returns hash
  #
  ############################
  def instance_find(path)
    result =   $evm.instance_find(path)
    # Returns Hash
    #$evm.log('info',"Instance:<#{path}> properties:<#{result.inspect}>") if @debug
    return result
  end


  ############################
  #
  # Method: instance_exists
  # Notes: Returns string: true/false
  #
  ############################
  def instance_exists(path)
    result = $evm.instance_exists(path)
    if result
      $evm.log('info',"Instance:<#{path}> exists. Result:<#{result.inspect}>") if @debug
    else
      $evm.log('info',"Instance:<#{path}> does not exist. Result:<#{result.inspect}>") if @debug
    end
    return result
  end


  ############################
  #
  # Method: instance_update
  # Notes: Returns string: true/false
  #
  ############################
  def instance_update(path, hash)
    result = $evm.instance_update(path, hash)
    if result
      $evm.log('info',"Instance: <#{path}> updated. Result:<#{result.inspect}>") if @debug
    else
      $evm.log('info',"Instance: <#{path}> not updated. Result:<#{result.inspect}>") if @debug
    end
    return result
  end


  ############################
  #
  # Method: validate_ipaddr
  # Notes: This method uses a regular expression to validate the ipaddr and gateway
  # Returns: Returns string: true/false
  #
  ############################
  def validate_ipaddr(ip)
    ip_regex = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
    if ip_regex =~ ip
      $evm.log("info","IP Address:<#{ip}> passed validation") if @debug
      return true
    else
      $evm.log("error","IP Address:<#{ip}> failed validation") if @debug
      return false
    end
  end


  ############################
  #
  # Method: validate_gateway
  # Notes: This method uses a regular expression to validate the gateway
  # Returns: Returns string: true/false
  #
  ############################
  def validate_gateway(ip)
    ip_regex = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
    if ip_regex =~ ip
      $evm.log("info","Default Gateway:<#{ip}> passed validation") if @debug
      return true
    else
      $evm.log("error","Default Gateway:<#{ip}> failed validation") if @debug
      return false
    end
  end

  ############################
  #
  # Method: validate_submask
  # Notes: This method uses a regular expression to validate the submask
  # Returns: Returns string: true/false
  #
  ############################
  def validate_submask(submask)
    mask_regex = /^(0|128|192|224|240|248|252|254|255).(0|128|192|224|240|248|252|254|255).(0|128|192|224|240|248|252|254|255).(0|128|192|224|240|248|252|254|255)$/
    if mask_regex =~ submask
      $evm.log("info","Subnet Mask:<#{submask}> passed validation") if @debug
      return true
    else
      $evm.log("error","Subnet Mask:<#{submask}> failed validation") if @debug
      return false
    end
  end

  ############################
  #
  # Method: set_displayname
  # Notes: This method set an instance DisplayName
  # Returns: Returns: true/false
  #
  ############################
  def set_displayname(path,display_name)
    result = $evm.instance_set_display_name(path, display_name)
    return result
  end


  ###################################
  #
  # Method: boolean
  #
  ###################################
  def boolean(string)
    return true if string == true || string =~ (/(true|t|yes|y|1)$/i)
    return false if string == false || string.nil? || string =~ (/(false|f|no|n|0)$/i)

    # Return false if string does not match any of the above
    $evm.log("info","Invalid boolean string:<#{string}> detected. Returning false") if @debug
    return false
  end

  # Set value to true to use hostname in IPAMDB, else set to false
  get_hostname = nil
  get_hostname ||= $evm.object['get_hostname'] || false

  # Set value to true to use vlan in IPAMDB, else set to false
  get_vlan = nil
  get_vlan ||= $evm.object['get_vlan'] || false

  # Set value to true to use IP information in IPAM DB, else set to false
  get_ipaddr = nil
  get_ipaddr ||= $evm.object['get_ipaddr'] || true


  # Get Provisioning Object
  prov = $evm.root["miq_provision"]

  # Get template from Provisioning Object
  template = prov.vm_template
  #$evm.log("info","Inspecting Template Cluster: <#{template.ems_cluster.inspect}>") if @debug

  # Set path to IPAM DB in automate or retrieve from model
  path_to_db = nil
  path_to_db ||= $evm.object['path_to_db']
  path_to_db = path_to_db.chomp('/') unless path_to_db.nil?

  search_path = "#{path_to_db}/*"

  # Call instance_find to pull back a hash of instances
  instance_hash = instance_find("#{search_path}")
  raise "No instances found in <#{search_path.inspect}>" if instance_hash.empty?


  # Remove hash elements where inuse = true
  instance_hash.delete_if {|k,v| v['inuse'] == 'true' || v['inuse'] == 'TRUE' }
  raise "No IP Addresses are free" if instance_hash.empty?
  #$evm.log("info","Inspecting instance_hash:<#{instance_hash.inspect}>") if @debug

  # This section is commented out until i figure out the sorting of IP Addresses
  # Sort the hashes by hash value ipaddr
  #instance_array = instance_hash.sort_by {|key,val| val['ipaddr'].split('.').map{ |digits| digits.to_i }}


  # Look for IP Address candidate that validates ipaddr, gateway and submask
  ip_candidate = instance_hash.find {|k,v| validate_ipaddr(v['ipaddr']) && validate_gateway(v['gateway']) && validate_submask(v['submask'])}
  raise "No available IP Addresses found:<#{ip_candidate.inspect}>" if ip_candidate.nil?

  # Update provisioning object with ip_candidate information
  class_instance = ip_candidate.first
  location = "#{path_to_db}/#{class_instance}"

  new_hash = ip_candidate.last
  $evm.log("info","Found instance:<#{location}> with Values:<#{new_hash.inspect}>") if @debug

  # Set inuse to true
  new_hash['inuse'] = 'true'

  
  # Override Customization Specification
  prov.set_option(:sysprep_spec_override, [true, 1])

  # Use VLAN information from acquired VLAN
  if boolean(get_vlan)
    prov.set_vlan(new_hash['vlan'])
    $evm.log("info","Provision object updated: [:vlan=>#{prov.options[:vlan].last}]")
  end

  # Use vm_name information from acquired hostname
  if boolean(get_hostname)
    prov.set_option(:vm_target_name, new_hash['hostname'])
    prov.set_option(:linux_host_name, new_hash['hostname'])
    prov.set_option(:vm_target_hostname, new_hash['hostname'])
    prov.set_option(:host_name, new_hash['hostname'])
    $evm.log("info","Provision object updated: [:vm_target_name=>#{prov.options[:vm_target_name]}]")
  end

  # Use networking information from acquired information
  if boolean(get_ipaddr)
    prov.set_option(:addr_mode, ["static", "Static"])

    prov.set_option(:ip_addr, new_hash['ipaddr'])
    prov.set_option(:subnet_mask, new_hash['submask'])
    prov.set_option(:gateway, new_hash['gateway'])

    #prov.set_nic_settings(0, {:ip_addr=>new_hash['ipaddr'], :subnet_mask=>new_hash['submask'], :gateway=>new_hash['gateway'], :addr_mode=>["static", "Static"]})
    $evm.log("info", "Provision Object Updated: [:ip_addr=>#{prov.options[:ip_addr].inspect},:subnet_mask=>#{prov.options[:subnet_mask].inspect},:gateway=>#{prov.options[:gateway].inspect},:addr_mode=>#{prov.options[:addr_mode].inspect} ]") if @debug
  end

  # Build instance display name
  if boolean(get_hostname)
    displayname = "#{new_hash['ipaddr']}-#{new_hash['hostname']}"
  else
    displayname = "#{new_hash['ipaddr']}-#{prov.get_option(:vm_target_name).to_s.strip}"
    # Update instance hostname
    new_hash['hostname'] = prov.get_option(:vm_target_name).to_s.strip
  end

  # Set date time acquired
  new_hash['date_released'] = nil
  new_hash['date_acquired'] = Time.now.strftime('%a, %b %d, %Y at %H:%M:%S %p')


  # Update instance and displayname
  if instance_update(location, new_hash)
    # Set Displayname of instance to reflect acquired IP Address
    set_displayname(location,displayname)
  else
    raise "Failed to update instance:<#{location}>"
  end

  #
  # Exit method
  #
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
