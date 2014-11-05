# VMware_Host_DVS_List

HOST_ID = 2

def get_host_dvs(dest_host, vim)
  switches = {}
  dvs = vim.queryDvsConfigTarget(vim.sic.dvSwitchManager, dest_host.ems_ref_obj, nil) rescue nil

  # List the names of the non-uplink portgroups.
  unless dvs.nil? || dvs.distributedVirtualPortgroup.nil?
    nupga = vim.applyFilter(dvs.distributedVirtualPortgroup, 'uplinkPortgroup' => 'false')
    nupga.each { |nupg| switches["dvs_#{nupg.portgroupName}"] = "#{nupg.portgroupName} (#{nupg.switchName})"}
  end

  return switches
end

begin
  st = Time.now
  host = Host.find_by_id(HOST_ID)
  vim = host.ext_management_system.connect
  dvs = get_host_dvs(host, vim)
  require 'pp'
  pp dvs
ensure
  vim.disconnect if vim rescue nil
  puts "MIQ(#{self.class.name}.allowed_dvs) Network DVS collection completed in [#{Time.now-st}] seconds"
end
