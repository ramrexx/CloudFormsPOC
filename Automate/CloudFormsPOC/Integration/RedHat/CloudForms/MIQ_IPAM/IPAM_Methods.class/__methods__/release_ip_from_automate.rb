# Release_IP_From_Automate.rb
#
# Description: This method releases IP Address information from CFME Automate Model
#
def log(level, msg)
  $evm.log(level, "#{msg}")
end

def instance_get(path)
  result = $evm.instance_get(path)
  log('info',"Instance: #{path} properties: #{result.inspect}")
  return result
end

def instance_find(path)
  return $evm.instance_find(path)
end

def instance_update(path, hash)
  result = $evm.instance_update(path, hash)
  if result
    log('info', "Instance: #{path} updated. Result:<#{result.inspect}>")
  else
    log('info', "Instance: #{path} not updated. Result:<#{result.inspect}>")
  end
  return result
end

def instance_exists(path)
  result = $evm.instance_exists?(path)
  if result
    log('info', "Instance:<#{path}> exists. Result:<#{result.inspect}>")
  else
    log('info', "Instance:<#{path}> does not exist. Result:<#{result.inspect}>")
  end
  return result
end

def validate_hostname(hostname)
  hostname_regex = /(hostname)$/
  if hostname_regex =~ hostname
    log("info", "Hostname: #{hostname} found")
    return true
  else
    log("error", "Hostname: #{hostname} not found")
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
raise "No instance found in #{search_path}" if instance_hash.nil?
#$evm.log("info","Found instances in:<#{search_path}> with Values:<#{instance_hash.inspect}>")

# Look for IP Address candidate that validates hostname and stuff into an array
ip_candidate = instance_hash.find {|k,v| v['hostname'] == vm.name.strip}
if ip_candidate.nil?
  log(:info, "Could not find intance for VM: #{vm.name}")
  exit MIQ_OK
end

# Assign first element in array to the instance name
class_instance = ip_candidate.first

# Assign last element to new_hash
new_hash = ip_candidate.last

location = "#{path_to_db}/#{class_instance}"
log("info", "Found instance: #{location} with Values: #{new_hash.inspect}")

# Set the inuse attribute to false
new_hash['inuse'] = 'false'
new_hash['date_released'] = Time.now.strftime('%a, %b %d, %Y at %H:%M:%S %p')
new_hash['date_acquired'] = nil

# Update instance and display name
if instance_update(location, new_hash)
  $evm.instance_set_display_name(location, nil)
else
  exit MIQ_STOP
end
