###################################
#
# CFME Automate Method: F5_Pools_AddMember
#
# Author: Kevin Morey
#
# This method adds a VM to an F5 pool and can either be called via a button or during provisioning
#
# Notes:
# - Gem requirements: gem install savon -v 2.3.3
# - Parameters for $evm.root['vmdb_object_type'] = 'vm'
#   - vm.ipaddresses
#   - $evm.root['dialog_option_0_f5_pool']
#   - $evm.root['dialog_option_0_f5_port']
#
# - Parameters for $evm.root['vmdb_object_type'] = 'miq_provision'
#   - prov.vm.ipaddresses
#   - prov.get_option(:f5_pool) || ws_values[:f5_pool]
#   - prov.get_option(:f5_port) || ws_values[:f5_port]
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'F5_Pools_AddMember'
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
    return response.to_hash["#{soap_action}_response".to_sym][:return]
  end

  # process_tags - create categories and tags
  def process_tags(category, single_value, tag)
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.to_s.downcase.gsub(/\W/, '_')
    tag_name = tag.to_s.downcase.gsub(/\W/, '_')
    log(:info, "Converted category name:<#{category_name}> Converted tag name: <#{tag_name}>")
    # if the category exists else create it
    unless $evm.execute('category_exists?', category_name)
      log(:info, "Category <#{category_name}> doesn't exist, creating category")
      $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category.titleize}")
    end
    # if the tag exists else create it
    unless $evm.execute('tag_exists?', category_name, tag_name)
      log(:info, "Adding new tag <#{tag_name}> in Category <#{category_name}>")
      $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag}")
    end
  end

  # basic retry logic
  def retry_method(retry_time=1.minute)
    log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  case $evm.root['vmdb_object_type']

  when 'miq_provision'
    prov = $evm.root['miq_provision']
    log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

    if prov.options.has_key?(:ws_values)
      ws_values = prov.options[:ws_values]
    end
    f5_pool = prov.get_option(:f5_pool) || ws_values[:f5_pool]
    raise "prov.get_option(:f5_pool) || ws_values[:f5_pool] not found. Skipping method" if f5_pool.nil?
    f5_port = prov.get_option(:f5_port) || ws_values[:f5_port]

    # get vm object from miq_provision
    vm = prov.vm
    raise "$evm.root['miq_provision'].vm not found" if vm.nil?

    # Since this is provisioning we need to put in retry logic to wait until IP Addresses are populated.
    unless vm.ipaddresses.empty?
      log(:info, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> present.")
    else
      log(:warn, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> not present.")
      retry_method()
    end

  when 'vm'
    # get vm from root
    vm = $evm.root['vm']
    log(:info, "Found VM:<#{vm.name}>")

    f5_pool = $evm.root['dialog_option_0_f5_pool']
    raise "$evm.root['dialog_option_0_f5_pool'] not found" if f5_pool.nil?

    # get port from dialog else default to port 80
    f5_port = $evm.root['dialog_option_0_f5_port']
    unless vm.ipaddresses.empty?
      log(:info, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> present.")
    end
    # Bail out if VM does not have any IP addresses assigned
    raise "VM:<#{vm.name}> IP addresse(s):<#{vm.ipaddresses.inspect}> not present." if vm.ipaddresses.empty?
  else
    raise "Invalid $evm.root['vmdb_object_type']:<#{$evm.root['vmdb_object_type']}>. Skipping method."
  end

  # default to port 80 if none was specified
  f5_port ||= '80'
  log(:info, "Processing VM:<#{vm.name} IP address:<#{vm.ipaddresses}> f5_pool:#{f5_pool} f5_port:<#{f5_port}>")

  # Loop through each ip address
  vm.ipaddresses.each do |vm_ipaddress|
    body_hash = {}
    body_hash[:pool_names] = {:item => [f5_pool]}
    body_hash[:members] = [{:items => { :member => {:address => vm_ipaddress, :port => f5_port} } } ]

    # call f5 and return a hash of pool names
    f5_return = call_F5_Pool(:add_member, body_hash)
    # Create tags if they do not already exist
    process_tags('f5_pool', true, f5_pool)

    # Tag vm with f5_pool
    unless vm.tagged_with?('f5_pool', f5_pool)
      log(:info, "Assigning new tag:<f5_pool/#{f5_pool}> to VM:<#{vm.name}>")
      vm.tag_assign("f5_pool/#{f5_pool}")
    end
  end

  # Log all of the provisioning options to the automation.log
  prov.options.each { |k,v| log(:info, "Provisioning Option Key:<#{k.inspect}> Value:<#{v.inspect}>") } unless prov.nil?
  
  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
