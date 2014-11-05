###################################
#
# CFME Automate Method: NetApp_WFA_CreateStorage
#
# Notes: This method leverages the Ruby REST API to call NetApp's WFA to create a storage
#
# Inputs: 
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'NetApp_WFA_CreateStorage'
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
  def call_netapp_wfa(action)
    require 'rest_client'
    require 'xmlsimple'

    servername = nil || $evm.object['servername']
    username = nil || $evm.object['username']
    password = nil || $evm.object.decrypt('password')

    log(:info, "Calling -> NetApp:<https://#{servername}> action:<#{action}>")

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
    return response_hash
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
