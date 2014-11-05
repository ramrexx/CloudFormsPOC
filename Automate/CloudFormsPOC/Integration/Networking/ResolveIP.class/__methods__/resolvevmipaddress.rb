###################################
#
# CFME Automate Method: ResolveVMIPAddress
#
# Notes: This method leverages the Ruby DNS Resolver to resolve a VMs IP Addresses
#
# Inputs: $evm.root['vm']
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'ResolveVMIPAddress'
    $evm.log(level, "#{@method} - #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # Use Ruby DNS Resolver class to see if the IP Addresse(s) of a VM resolve
  def valid_hostname?(ip)
    # Require Ruby DNS Resolver
    require 'resolv'
    valid = true
    begin
      Resolv.getaddress(ip)
    rescue Resolv::ResolvError
      valid = false
    end
    return valid
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  vm = $evm.root['vm']
  raise "$evm.root['vm'] object not found"

  # For each ip address assigned to a VM validate it
  vm.ipaddresses.each do |ip|
    valid = valid_hostname?(ip)
    log(:info, "#{ip} valid? #{valid.inspect}")
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
