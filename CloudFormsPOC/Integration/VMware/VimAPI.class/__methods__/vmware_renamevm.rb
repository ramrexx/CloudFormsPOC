###################################
#
# CFME Automate Method: VMware_RenameVM
#
# Notes: This method renames a VMware VM
#
###################################
begin
  # Method for logging
  def log(level, msg)
    @method = 'VMware_RenameVM'
    $evm.log(level, "#{@method} - #{msg}")
  end

  # dump_root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def authLogin(username, password, server, resource)
    http = Net::HTTP.new("#{server}", 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    path = "#{resource}"

    data = <<-EOF
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
    <soapenv:Header/>
    <soapenv:Body>
    <urn:Login>
    <urn:_this>SessionManager</urn:_this>
    <urn:userName>#{username}</urn:userName>
    <urn:password>#{password}</urn:password>
    </urn:Login>
    </soapenv:Body>
    </soapenv:Envelope>
    EOF

    # Set Headers
    headers = { 'Content-Type' => 'text/xml' }

    # Post the request
    resp, data = http.post(path, data, headers)
    cookie = ""
    # Output the results
    resp.each { |key, val| cookie = val if key == 'set-cookie' }
    log(:info, "AuthLogin Response #{resp.code}")
    log(:info, "AuthLogin Cookie #{cookie}")
    return cookie
  end

  def call_vSphere(cookie, server, ems_ref, new_vmname)
    http = Net::HTTP.new("#{server}", 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    path = '/sdk/vimService/'

    data = <<-EOF
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
    <soapenv:Header/>
    <soapenv:Body>
    <urn:Rename_Task>
    <urn:_this type="VirtualMachine">#{ems_ref}</urn:_this>
    <urn:newName>#{new_vmname}</urn:newName>
    </urn:Rename_Task>
    </soapenv:Body>
    </soapenv:Envelope>
    EOF

    # Set Headers
    headers = { 'Cookie' => cookie }
    # Post the request
    resp, data = http.post(path, data, headers)
    log(:info, "Rename_Task Response: #{resp.code}")
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  #dump_root()

  require 'net/http'
  require 'net/https'
  require 'json'
  require 'xmlsimple'
  require 'cgi'

  vm = $evm.root['vm']
  raise "Invalid VM vendor: #{vm.vendor}" unless vm.vendor.downcase == 'vmware'

  server = vm.ext_management_system.ipaddress
  username = vm.ext_management_system.authentication_userid
  password = vm.ext_management_system.authentication_password
  resource = "/sdk/vimService/"
  new_vmname = $evm.root['dialog_new_vmname']
  
  unless new_vmname.nil?
    log(:info, "Current VM Name: #{vm.name}")
    log(:info, "Current vSphere VM Name: #{vm.ems_ref}")
    log(:info, "Current vSphere VM UUID: #{vm.uid_ems}")
    cookie = authLogin(username, password, server, resource)
    log(:info, "Renaming VM: #{vm.name} to #{new_vmname}")
    results = call_vSphere(cookie, server, vm.ems_ref, new_vmname)
    log(:info, "results: #{results.inspect}")
  else
    log(:info, "New VM Name not found")
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  retry_method()
  exit MIQ_ABORT
end
