# delete_record.rb
#
# Author: Carsten Clasohm
# License: GPL v3
#
# Description:
#   During retirement, delete a VM's dynamic DNS entry.

def error(msg)
  $evm.log(:error, "#{msg}")
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg
  exit MIQ_OK
end

begin
  vm = $evm.root['vm']

  # This was set by the add_record method.
  dns_domain = vm.custom_get('dns_domain')

  if dns_domain
    fqdn = "#{vm.name}.#{dns_domain}"

    ddns_server = $evm.object['servername']
    ddns_keyname = $evm.object['keyname']
    ddns_keyvalue = $evm.object['keyvalue']

    $evm.log(:info, "Deleting DNS entry #{fqdn} A")

    IO.popen("nsupdate", 'r+') do |f|
      f << <<-EOF
        server #{ddns_server}
        key #{ddns_keyname} #{ddns_keyvalue}
        zone #{dns_domain}
        update delete #{fqdn} A
        send
      EOF

      f.close_write
    end
  end
  
rescue => err
  error("[#{err}]\n#{err.backtrace.join("\n")}")
end
