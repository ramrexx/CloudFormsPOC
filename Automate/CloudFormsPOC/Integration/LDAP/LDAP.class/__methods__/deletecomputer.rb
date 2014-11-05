###################################
#
# CFME Automate Method: DeleteComputer
#
# Author: Kevin Morey
#
# Notes: This method seraching LDAP for a computer then attempts to delete the computer account
#
###################################
begin
  # Method for logging
  def log(level, msg, update_message=false)
    @method = 'DeleteComputer'
    $evm.log(level, "#{@method} - #{msg}")
    $evm.root['miq_provision'].message = "#{@method} - #{msg}" if $evm.root['miq_provision'] && update_message
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # call_ldap
  def call_ldap(computer_name)
    require 'rubygems'
    require 'net/ldap'

    # get parameters
    servername = nil || $evm.object['servername']
    username = nil || $evm.object['username']
    password = nil || $evm.object.decrypt('password')
    basedn = nil || $evm.object['basedn']

    # setup authentication to LDAP
    ldap = Net::LDAP.new :host => servername, :port => 389,
    :auth => {
      :method => :simple,
      :username => "cn=#{username}, cn=users, #{basedn}",
      :password => password
    }

    # Search LDAP for computername
    log(:info, "Searching LDAP server: #{servername} basedn: #{basedn} for computer: #{computer_name}")
    filter = Net::LDAP::Filter.eq("cn", computer_name)
    computer_dn = nil
    ldap.search(:base => basedn, :filter => filter) {|entry| computer_dn = entry.dn }
    raise "computer_dn: #{computer_dn} not found" if computer_dn.blank?

    log(:info, "Found computer_dn: #{computer_dn.inspect}")
    log(:info, "Deleting computer_dn from LDAP")
    ldap.delete(:dn => computer_dn)
    result = ldap.get_operation_result.code
    if result.zero?
      log(:info, "Successfully deleted computer_dn: #{computer_dn} from LDAP Server", true)
    else
      log(:warn, "Failed to delete computer_dn: #{computer_dn} from LDAP Server", true)
    end
    return result
  end

  log(:info, "CFME Automate Method Started", true)

  # dump all root attributes to the log
  dump_root()
  case $evm.root['vmdb_object_type']
  when 'miq_provision'
    prov = $evm.root['miq_provision']
    computer_name = prov.get_option(:vm_target_hostname)
  when 'vm'
    vm = $evm.root['vm']
    computer_name = vm.name
  end

  results = call_ldap(computer_name)
  log(:info, "Inspecting delete results: #{results.inspect}")

  # Exit method
  log(:info, "CFME Automate Method Ended", true)
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
