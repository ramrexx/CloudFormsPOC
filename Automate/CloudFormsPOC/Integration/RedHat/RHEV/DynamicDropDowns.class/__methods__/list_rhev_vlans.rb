# list_rhev_vlans.rb
#
# Author: Carsten Clasohm
# License: GPL v3
#
# Description: Lists all availabe RHEV networks.
#

def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg
  exit MIQ_OK
end

begin
  # Get the list of networks through the RHEV API.
  def get_networks(provider_id)
    require 'rest_client'
    require 'nokogiri'

    provider = $evm.vmdb(:ems_redhat, provider_id)
    
    servername = provider.hostname
    username = provider.authentication_userid
    password = provider.authentication_password

    $evm.log(:info, "Calling -> RHEVM:<https://#{servername}/api/networks>>")
    response = RestClient::Request.new(
      :method => :get,
      :url => "https://#{servername}/api/networks",
      :verify_ssl => false,
      :user => username,
      :password => password,
      :headers => {
        :accept=>'application/xml',
        :content_type=>'application/xml'
      }
    ).execute
    unless response.code == 200
      raise "Failure <- RHEVM Response:<#{response.code}>"
    else
      $evm.log(:info, "Success <- RHEVM Response:<#{response.code}>")
    end
    
    results = Nokogiri::XML.parse(response)
    return results.xpath('/networks/network')
  end

  # build_dialog
  def build_dialog(networks)
    if $evm.root['required'] == 'true'
      dialog_hash = {'' => ' < Choose >'}
    else
      dialog_hash = {'' => ' < None >'}
    end
    
    networks.each do |network|
      id = network.attributes['id'].content
      name = network.xpath('name')[0].content

      # Exclude the management network.
      next if name == 'rhevm'
      
      label = name
      unless network.xpath('description').blank?
        label = network.xpath('description')[0].content
      end
      
      dialog_hash[name] = label
    end

    $evm.object['values'] = dialog_hash
    $evm.log(:info, "Dynamic drop down values: #{dialog_field['values']}")
  end

  # This can be called either from a VM button, or from a service provisioning dialog.
  vm = $evm.root['vm']
  if vm
    provider_id = vm.ext_management_system.id
    $evm.log(:info, "Using provider_id #{provider_id} from VM #{vm.name}")
  else
    provider_id = $evm.root['provider_id']
    
    if provider_id
      $evm.log(:info, "Using provider_id #{provider_id} from dialog")
    else
      rhev_providers = $evm.vmdb(:ems_redhat).all
      provider_id = rhev_providers[0].id unless rhev_providers.length > 1
      
      $evm.log(:info, "Using first RHEV provider #{provider_id}")
    end
  end

  if provider_id
    networks = get_networks(provider_id)
    build_dialog(networks)
  else
    $evm.object['values'] = { '' => '< Choose Provider and Refresh >'}
  end

rescue => err
  error("[#{err}]\n#{err.backtrace.join("\n")}")
end
