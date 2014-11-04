###################################
#
# CFME Automate Method: VMware_UnmountToolsInstaller
#
# Notes: This method unmounts VMware Tools installer CD. 
#
###################################
begin
  # Method for logging
  def log(level, msg)
    @method = 'VMware_UnmountToolsInstaller'
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

  def call_vSphere(cookie, server, ems_ref)
    http = Net::HTTP.new("#{server}", 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    path = '/sdk/vimService/'

    data = <<-EOF
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:vim25">
    <soapenv:Header/>
    <soapenv:Body>
    <urn:UnmountToolsInstaller>
    <urn:_this type="VirtualMachine">#{ems_ref}</urn:_this>
    </urn:UnmountToolsInstaller>
    </soapenv:Body>
    </soapenv:Envelope>
    EOF

    # Set Headers
    headers = { 'Cookie' => cookie }
    # Post the request
    resp, data = http.post(path, data, headers)
    log(:info, "UnmountToolsInstaller Response: #{resp.code}")
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

  server = vm.ext_management_system.ipaddress
  username = vm.ext_management_system.authentication_userid
  password = vm.ext_management_system.authentication_password
  resource = "/sdk/vimService/"

  if vm.vendor.downcase == 'vmware'
    log(:info, "Current VM Name: #{vm.name}")
    log(:info, "Current vSphere VM Name: #{vm.ems_ref}")
    log(:info, "Current vSphere VM UUID: #{vm.uid_ems}")
    cookie = authLogin(username, password, server, resource)
    log(:info, "Unmounting VMware Tools on VM: #{vm.name}")
    results = call_vSphere(cookie, server, vm.ems_ref)
    log(:info, "results: #{results.inspect}")
  else
    log(:info, "Invalid VM vendor: #{vm.vendor}")
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
