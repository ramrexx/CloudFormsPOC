#
# Description: This method is used to apply PreProvision customizations for Amazon provisioning
#

# Get provisioning object
prov = $evm.root['miq_provision']

$evm.log("info", "Provisioning ID:<#{prov.id}> Provision Request ID:<#{prov.miq_provision_request.id}> Provision Type: <#{prov.provision_type}>")

# Log all of the provisioning options to the automation.log
prov.options.each { |k,v| $evm.log(:info, "Provisioning Option Key:<#{k.inspect}> Value:<#{v.inspect}>") }
