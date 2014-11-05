###################################
#
# CFME Automate Method: AddComputer
#
# Author: Kevin Morey
#
# Notes: This method is will create a computer in Active Directory
#  - gem requirements net/ldap
#  - vmdb_object_type: $evm.root['vm']
#
###################################
begin
  # Method for logging
  def log(level, message)
    @method = 'AddComputer'
    $evm.log(level, "#{@method} - #{message}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # call_ldap
  def call_ldap(vm)
    require 'rubygems'
    require 'net/ldap'

    # get parameters 
    servername = nil || $evm.object['servername']
    username = nil || $evm.object['username']
    password = nil || $evm.object.decrypt('password')
    basedn = nil || $evm.object['basedn']
    ou = "ou=CloudForms, #{basedn}"
    dn = "cn=#{vm.name}, #{ou}"

    # setup authentication to LDAP
    ldap = Net::LDAP.new :host => servername,
      :port => 389,
    :auth => {
      :method => :simple,
      :username => "cn=#{username}, cn=users, #{basedn}",
      :password => password
    }

    # configure ldap attributes
    attributes = {
      :cn => vm.name,
      :objectclass => ["top", "computer"],
      :samaccountname => vm.name,
      :useraccountcontrol => '4128'
    }

    log(:info, "Calling ldap:<#{servername}> dn:<#{basedn}> attributes:<#{attributes}>")
    ldap.add(:dn => dn, :attributes => attributes)
    result = ldap.get_operation_result.code
    if result.zero?
      log(:info, "Successfully added computer:<#{vm.name}> do LDAP Server")
    else
      log(:warn, "Failed to add computer:<#{vm.name}> do LDAP Server")
    end
    return result
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  dump_root

  # get vm object from root
  vm = $evm.root['vm']
  raise "$evm.root['vm'] not found" if vm.nil?
  log(:info, "Found VM:<#{vm.name}>")

  result = call_ldap(vm)

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
