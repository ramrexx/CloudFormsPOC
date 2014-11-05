#
# service_request_pending.rb
#
# Description: This method is executed when the service request is NOT auto-approved
#

# get the request object from root
miq_request = $evm.root['miq_request']
log(:info, "miq_request.id:<#{miq_request.id}> miq_request.options[:dialog]:<#{miq_request.options[:dialog].inspect}>")

# lookup the service_template object
service_template = $evm.vmdb(miq_request.source_type, miq_request.source_id)
log(:info, "service_template id:<#{service_template.id}> service_type:<#{service_template.service_type}> description:<#{service_template.description}> services:<#{service_template.service_resources.count}>")

# Get objects
msg = $evm.object['reason']
log(:info, "#{msg}")

# Raise automation event: request_pending
miq_request.pending
