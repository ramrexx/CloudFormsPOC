###################################
#
# EVM Automate Method: IPAM_Release_from_MIQ
#
# Notes: EVM Automate method to release IP Address information from EVM Automate Model
#
###################################
begin
  @method = 'IPAM_Release_from_MIQ'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true


  ############################
  #
  # Method: instance_get
  # Notes: Returns hash
  #
  ############################
  def instance_get(path)
    result = $evm.instance_get(path)
    # Returns Hash
    $evm.log('info',"Instance:<#{path}> properties:<#{result.inspect}>") if @debug
    return result
  end

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
  # Method: instance_exists
  # Notes: Returns string: true/false
  #
  ############################
  def instance_exists(path)
    result = $evm.instance_exists?(path)
    if result
      $evm.log('info',"Instance:<#{path}> exists. Result:<#{result.inspect}>") if @debug
    else
      $evm.log('info',"Instance:<#{path}> does not exist. Result:<#{result.inspect}>") if @debug
    end
    return result
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


  ############################
  #
  # Method: validate_hostname
  # Notes: This method uses a regular expression to find an instance that contains the hostname
  # Returns: Returns string: true/false
  #
  ############################
  def validate_hostname(hostname)
    hostname_regex = /(hostname)$/
    if hostname_regex =~ hostname
      $evm.log("info","Hostname:<#{hostname}> found") if @debug
      return true
    else
      $evm.log("error","Hostname:<#{hostname}> not found") if @debug
      return false
    end
  end

  # Get current VM object
  vm = $evm.root['vm']
  raise "VM not found" if vm.nil?

  # Set path to IPAM DB in automate or retrieve from model
  path_to_db = nil
  path_to_db ||= $evm.object['path_to_db']
  path_to_db = path_to_db.chomp('/') unless path_to_db.nil?

  search_path = "#{path_to_db}/*"

  # Find an instance that matches the VM's IP Address
  instance_hash = instance_find(search_path)
  raise "No instance found in <#{search_path}>" if instance_hash.nil?
  #$evm.log("info","Found instances in:<#{search_path}> with Values:<#{instance_hash.inspect}>") if @debug

  # Look for IP Address candidate that validates hostname and stuff into an array
  ip_candidate = instance_hash.find {|k,v| v['hostname'] == vm.name.strip}
  raise "Could not find intance for VM:<#{vm.name}>" if ip_candidate.nil?

  # Assign first element in array to the instance name
  class_instance = ip_candidate.first

  # Assign last element to new_hash
  new_hash = ip_candidate.last

  location = "#{path_to_db}/#{class_instance}"
  $evm.log("info","Found instance:<#{location}> with Values:<#{new_hash.inspect}>") if @debug

  # Set the inuse attribute to false
  new_hash['inuse'] = 'false'

  new_hash['date_released'] = Time.now.strftime('%a, %b %d, %Y at %H:%M:%S %p')
  new_hash['date_acquired'] = nil

  # Update instance and display name
  if instance_update(location, new_hash)
    set_displayname(location,nil)
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
