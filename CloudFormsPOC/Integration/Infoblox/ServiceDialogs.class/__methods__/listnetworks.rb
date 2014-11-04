###################################
#
# CFME Automate Method: ListNetworks
#
# Author: Kevin Morey
#
# Notes: This method is executed from a Dynamic Drop-down Service Dialog that will list all Infoblox networks and display them in the service dialog
# - gem requirements 'rest_client', 'xmlsimple', 'json'
# dialog_network_cidr
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'ListNetworks'
    $evm.log(level, "#{@method} - #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # call_infoblox
  def call_infoblox(action, ref='network' )
    require 'rest_client'
    require 'xmlsimple'
    require 'json'

    servername = nil || $evm.object['servername']
    username = nil || $evm.object['username']
    password = nil || $evm.object.decrypt('password')
    url = "https://#{servername}/wapi/v1.2.1/"+"#{ref}"

    params = {
      :method=>action,
      :url=>url,
      :user=>username,
      :password=>password,
      :headers=>{ :content_type=>:xml, :accept=>:xml }
    }
    log(:info, "Calling -> Infoblox:<#{url}> action:<#{action}> payload:<#{params[:payload]}>")

    response = RestClient::Request.new(params).execute
    raise "Failure <- Infoblox Response:<#{response.code}>" unless response.code == 200 || response.code == 201

    log(:info, "Success <- Infoblox Response:<#{response.code}>")
    # use XmlSimple to convert xml to ruby hash
    response_hash = XmlSimple.xml_in(response)
    log(:info, "Inspecting response_hash: #{response_hash.inspect}")
    return response_hash
  end

  # build_dialog
  def build_dialog(hash)
    dialog_field = $evm.object

    # set the values to the dialog_hash
    dialog_field['values'] = hash.keys
    # sort_by: value / description / none
    $evm.object["sort_by"] = "description"
    # sort_order: ascending / descending
    $evm.object["sort_order"] = "ascending"
    # data_type: string / integer
    $evm.object["data_type"] = "string"
    # required: true / false
    $evm.object["required"] = "true"

    log(:info, "Dynamic drop down values: #{$evm.object['values']}")
    return $evm.object['values']
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  # call infoblox to get a list of networks
  networks = call_infoblox(:get)

  # # only pull out the network and the _ref values
  networks_hash = Hash[*networks['value'].collect { |x| [x['network'], x['_ref'][0]] }.flatten]
  raise "networks_hash returned nil" if networks_hash.nil?
  log(:info, "Inspecting networks_hash:<#{networks_hash}>")

  build_dialog(networks_hash)

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
