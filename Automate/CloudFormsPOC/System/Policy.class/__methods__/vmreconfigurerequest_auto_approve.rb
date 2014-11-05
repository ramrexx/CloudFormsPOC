# VmReconfigureRequest_Auto_Approve.rb
# Kevin Morey
# Description: This method auto-approves the vm reconfiguration request
# Auto-Approve request
$evm.log("info", "AUTO-APPROVING")
$evm.root["miq_request"].approve("admin", "Auto-Approved")
