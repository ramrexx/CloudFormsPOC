###################################
#
# CFME Automate Method: Dialog_List_VLANS
#
# Author: Kevin Morey
#
# Notes: This method lists all availabe RHEVM VLANS for a dynamic drop down service catalog
# - gem requirements 'rest_client', 'xmlsimple'
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'Dialog_List_VLANS'
    $evm.log(level, "#{@method} - #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # call_rhevm
  def call_rhevm(action)
    require 'rest_client'
    require 'xmlsimple'

    servername = nil || $evm.object['servername']
    username = nil || $evm.object['username']
    password = nil || $evm.object.decrypt('password')

    log(:info, "Calling -> RHEVM:<https://#{servername}/api/networks> action:<#{action}>")
    response = RestClient::Request.new(
      :method=>action,
      :url=>"https://#{servername}/api/networks",
      :user=>username,
      :password=>password,
      :headers=>{
        :accept=>'application/xml',
        :content_type=>'application/xml'
      }
    ).execute
    unless response.code == 200
      raise "Failure <- RHEVM Response:<#{response.code}>"
    else
      log(:info, "Success <- RHEVM Response:<#{response.code}>")
    end
    # use XmlSimple to convert xml to ruby hash
    response_hash = XmlSimple.xml_in(response)
    log(:info, "Inspecting response_hash: #{response_hash['network'].inspect}")
    return response_hash['network']
  end

  # build_dialog
  def build_dialog(networks)
    dialog_field = $evm.object

    # set the values
    dialog_field['values'] = networks.collect { |net| net['name'] }

    # sort_by: value / description / none
    dialog_field["sort_by"] = "description"
    # sort_order: ascending / descending
    dialog_field["sort_order"] = "ascending"
    # data_type: string / integer
    dialog_field["data_type"] = "string"
    # required: true / false
    dialog_field["required"] = "true"
    log(:info, "Dynamic drop down values: #{dialog_field['values']}")
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  # build a dynamic drop down of all pools
  build_dialog(call_rhevm(:get))

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
