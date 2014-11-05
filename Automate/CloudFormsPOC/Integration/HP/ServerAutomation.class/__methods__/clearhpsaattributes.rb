#
#            Automate Method
#
$evm.log("info", "Automate Method Started")
#
#            Method Code Goes here
#
$evm.log(:info, "Clearing HPSA_server_id and HPSA_software_policy_id")
$evm.log(:info, "VM is <#{$evm.root['vm'].name}>")
vm = $evm.root['vm']
vm.custom_set("HPSA_server_id", nil)
vm.custom_set("HPSA_software_policy_id", nil)
$evm.log(:info, "HPSA_server_id is now #{vm.custom_get('HPSA_server_id')}")
$evm.log(:info, "HPSA_software_policy_id is now #{vm.custom_get('HPSA_software_policy_id')}")
#
#
#
$evm.log("info", "Automate Method Ended")
exit MIQ_OK
