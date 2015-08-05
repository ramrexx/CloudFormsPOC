# add_record.rb
#
# Author: Carsten Clasohm
# License: GPL v3
#
# Description:
#   Create a DNS A record for a VM name and an IP address that was acquired
#   earlier in the provisioning process. Assumes that the provisioning dialog
#   has a field for selecting the DNS domain.
#
#   Requires a DNS server like bind set up for dynamic DNS updates. For more
#   information, see "man nsupdate".

def error(msg)
  $evm.log(:error, "#{msg}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg
  exit MIQ_OK
end

begin
  prov = $evm.root['miq_provision']
  ws_values = prov.options[:ws_values]

  vm = prov.vm

  dns_domain = ws_values[:dns_domain]

  fqdn = "#{vm.name}.#{dns_domain}"

  ipaddress = prov.options[:ipaddr]

  ddns_server = $evm.object['servername']
  ddns_keyname = $evm.object['keyname']
  ddns_keyvalue = $evm.object['keyvalue']

  $evm.log(:info, "Creating DNS entry #{fqdn} A #{ipaddress}")
  
  IO.popen("nsupdate", 'r+') do |f|
    f << <<-EOF
      server #{ddns_server}
      key #{ddns_keyname} #{ddns_keyvalue}
      zone #{dns_domain}
      update add #{fqdn} 86400 A #{ipaddress}
      send
    EOF

    f.close_write
  end

  # This is used during VM retirement.
  vm.custom_set('dns_domain', dns_domain)

rescue => err
  error("[#{err}]\n#{err.backtrace.join("\n")}")
end
