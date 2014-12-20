
##################################################
#
# CFME Automate Method: Satellite6_Unsubscribe
#
# by Marco Berube
#
# Note:  Unsubscribe a VM from satellite based on
#        your VM FQDN
#
##################################################
begin

	require 'rest-client'
	require 'json'


	$satellite = nil || $evm.object['satellite']
	$username = nil || $evm.object['username']
	$password = nil || $evm.object.decrypt('password')
	domain = nil || $evm.object['domain']


	def find_system_by_hostname(hostname)
		response = JSON.parse(RestClient.get "https://#{$username}:#{$password}@#{$satellite}/katello/api/v2/systems?name=#{hostname}")
		return response['results'].last
	end

	def delete_system(system)
		uuid = system['uuid']
		RestClient.delete "https://#{$username}:#{$password}@#{$satellite}/katello/api/v2/systems/#{uuid}"
	end


	# Get vm object from the VM class versus the VmOrTemplate class
	vm = $evm.vmdb("vm", $evm.root['vm_id'])
	raise "$evm.root['vm'] not found" if vm.nil?
	$evm.log("info", "Found VM:<#{vm.name}>")

	# Find Satellite system record for this VM
	$evm.log("info", "Searching Satellite VM record : <#{vm.name}.#{domain}>")
	system = find_system_by_hostname("#{vm.name}.#{domain}")

	if system.nil?
		$evm.log("info", "Satellite system record not found for <#{vm.name}>") 
	else
		$evm.log("info", "Unsubscribing #{system['name']} : #{system['uuid']}")
		delete_system(system)
	end

	exit MIQ_OK


rescue => err
		$evm.log("info", "[#{err}]\n#{err.backtrace.join("\n")}")
		exit MIQ_STOP
end


