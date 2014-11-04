###################################
#
# CFME Automate Method: F5_Pools_GetList
#
# Author: Kevin Morey
#
# This method is executed from a Dynamic Drop-down Service Dialog that will list
# all F5 pools and display them in the dialog
#
# Notes:
# - Gem requirements: gem install savon -v 2.3.3
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'F5_Pools_GetList'
    $evm.log(level, "#{@method} - #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # call F5
  def call_F5_Pool(soap_action, body_hash=nil)
    servername = nil || $evm.object['servername']
    username = nil || $evm.object['username']
    password = nil || $evm.object.decrypt('password')

    # require necessary gems
    require "rubygems"
    gem 'savon', '=2.3.3'
    require "savon"
    require 'httpi'

    # configure httpi gem to reduce verbose logging
    HTTPI.log_level = :info # changing the log level
    HTTPI.log       = false # diable HTTPI logging
    HTTPI.adapter   = :net_http # [:httpclient, :curb, :net_http]

    # configure savon gem
    soap = Savon.client do |s|
      s.wsdl "https://#{servername}/iControl/iControlPortal.cgi?WSDL=LocalLB.Pool"
      s.basic_auth [username, password]
      s.ssl_verify_mode :none
      s.endpoint "https://#{servername}/iControl/iControlPortal.cgi"
      s.namespace 'urn:iControl:LocalLB/Pool'
      s.env_namespace :soapenv
      s.namespace_identifier :pool
      s.raise_errors false
      s.convert_request_keys_to :none
      s.log_level :error
      s.log false
    end

    log(:info, "Calling F5:<#{servername}> SOAP action:<#{soap_action.inspect}> SOAP Message:<#{body_hash.inspect}>")
    response = soap.call soap_action do |s|
      s.message body_hash unless body_hash.nil?
    end

    log(:info, "F5 Response: <#{response.to_hash.inspect}>")
    # Convert xml response to a hash
    return response.to_hash["#{soap_action}_response".to_sym][:return][:item]
  end

  # build_f5dropdown
  def build_f5dropdown(pools)
    dialog_hash = {}
    pools.each_with_index {|v, i| dialog_hash[v.to_s] = v.to_s}
    # sort_by: value / description / none
    $evm.object["sort_by"] = "description"
    # sort_order: ascending / descending
    $evm.object["sort_order"] = "ascending"
    # data_type: string / integer
    $evm.object["data_type"] = "string"
    # required: true / false
    $evm.object["required"] = "true"
    # set the values to the dialog_hash
    $evm.object['values'] = dialog_hash
    log(:info, "Dynamic drop down values: #{$evm.object['values']}")
    return $evm.object['values']
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  # call f5 and return a hash of pool names
  pools = call_F5_Pool(:get_list)
  log(:info, "List of F5 pools: #{pools.inspect}")
  raise "No F5 pools found" if pools.nil?

  # build a dynamic drop down of all pools
  dialog_hash = build_f5dropdown(pools)

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
