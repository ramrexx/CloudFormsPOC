#
# service_request_approved.rb
#
# Description: This method is executed when the service request is auto-approved
#

miq_request = $evm.root['miq_request']
$evm.log(:info, "miq_request.id:<#{miq_request.id}> miq_request.options[:dialog]:<#{miq_request.options[:dialog].inspect}>")

# lookup the service_template object
service_template = $evm.vmdb(miq_request.source_type, miq_request.source_id)
$evm.log(:info, "service_template id:<#{service_template.id}> service_type:<#{service_template.service_type}> description:<#{service_template.description}> services:<#{service_template.service_resources.count}>")

# Auto-Approve request
$evm.log(:info, "AUTO-APPROVING")
miq_request.approve("admin", "Auto-Approved")
