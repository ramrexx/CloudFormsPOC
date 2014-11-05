$evm.log("info", "********* InfoBlox - GetIP STARTED *********")


require 'rest_client'
require 'json'
require 'nokogiri'
require 'ipaddr'




##################################
# Get IP Address                 #
##################################
def getIP(hostname, ipaddress)
  begin
    url = 'https://' + @connection + '/wapi/v1.2.1/record:host'
    content = "\{\"ipv4addrs\":\[\{\"ipv4addr\":\"#{ipaddress}\"\}\],\"name\":\"#{hostname}\"\}"
    dooie = RestClient.post url, content, :content_type => :json, :accept => :json
    return true
  rescue Exception => e
    puts e.inspect
    puts dooie
    return false
  end
end


##################################
# Next Available IP Address      #
##################################
def nextIP(network)
  begin
    $evm.log("info", "GetIP --> NextIP on - #{network}")
    url = 'https://' + @connection + '/wapi/v1.2.1/' + network
    dooie = RestClient.post url, :_function => 'next_available_ip', :num => '1'
    doc = Nokogiri::XML(dooie)
    root = doc.root
    nextip = root.xpath("ips/list/value/text()")
    $evm.log("info", "GetIP --> NextIP is - #{nextip}")
    return nextip
  rescue Exception => e
    puts e.inspect
    return false
  end
end




##################################
# Fetch Network Ref              #
##################################
def fetchNetworkRef(cdir)
  begin
    $evm.log("info", "GetIP --> Network Search - #{cdir}")
    url = 'https://' + @connection + '/wapi/v1.2.1/network'
    dooie = RestClient.get url
    doc = Nokogiri::XML(dooie)
    root = doc.root
    networks = root.xpath("value/_ref/text()")
    networks.each do | a |
      a = a.to_s
      unless a.index(cdir).nil?
        $evm.log("info", "GetIP --> Network Found - #{a}")
        return a
      end
    end
    return nil
  rescue Exception => e
    puts e.inspect
    return false
  end
end




##################################
# Set netmask                        #
##################################
def netmask(cdir)
  netblock = IPAddr.new(cdir)
  netins =  netblock.inspect
  netmask = netins.match(/(?<=\/)(.*?)(?=\>)/)
  $evm.log("info", "GetIP --> Netmask = #{netmask}")
  return netmask
end


##################################
# Set Options in prov                                       #
##################################
def set_prov(prov, hostname, ipaddr, netmask, gateway)
  $evm.log("info", "GetIP --> Hostname = #{hostname}")
  $evm.log("info", "GetIP --> IP Address =  #{ipaddr}")
  $evm.log("info", "GetIP -->  Netmask = #{netmask}")
  $evm.log("info", "GetIP -->  Gateway = #{gateway}")
  prov.set_option(:sysprep_spec_override, 'true')
  prov.set_option(:addr_mode, ["static", "Static"])
  prov.set_option(:ip_addr, "#{ipaddr}")
  prov.set_option(:subnet_mask, "#{netmask}")
  prov.set_option(:gateway, "#{gateway}")
  prov.set_option(:vm_target_name, "#{hostname}")
  prov.set_option(:linux_host_name, "#{hostname}")
  prov.set_option(:vm_target_hostname, "#{hostname}")
  prov.set_option(:host_name, "#{hostname}")
  $evm.log("info", "GetIP --> #{prov.inspect}")


end


##################################
# Find my environment            #
##################################
def find_environment(environment)
  case environment


  when "qa"
    $evm.log("info","qa")


    @gateway = "192.168.1.254"
    @network = "192.168.1.0/24"
    @dnsdomain = "acme.com"


  when "test"
    $evm.log("info","test")


    @gateway = "192.168.2.254"
    @network = "192.168.1.0/24"
    @dnsdomain = "acme.com"


  when "prod"
    $evm.log("info","production")


    @gateway = "10.11.164.1"
    @network = "10.11.164.0/24"
    @dnsdomain = "redhatlab.com"


  else
    $evm.log("info","NOTHING")
    environment = "prod"

  end
end


#-----------------------MAIN PROGRAM-----------------------#


action = "getipnext"


username = "admin"
password = "infoblox"
server = "10.11.164.230"
@connection = "#{username}:#{password}@#{server}"
@staticIP = "10.11.164.231"


prov = $evm.root["miq_provision"]
$evm.log("info","#{prov.inspect}")


dialog_options = prov.miq_provision_request.options[:dialog]
$evm.log("info","GetIP --> Dialog Options = #{dialog_options}")

# Get provisioning object tags
prov_tags = prov.get_tags
infoblox = prov_tags[:infoblox]

if infoblox == "y"
environment = "prod"
  $evm.log("info", "********IPAM Selected Using Production******")

    else
environment = nil
  $evm.log("info", "********IPAM Not Used*********")

end

find_environment(environment)


case action

when "getipnext"
  netRef = fetchNetworkRef(@network)
  nextIPADDR = nextIP(netRef)
  result = getIP("#{prov.options[:vm_target_name]}.#{@dnsdomain}", nextIPADDR)
  if result ==  true
    $evm.log("info", "GetIP --> #{prov.options[:vm_target_name]}.#{@dnsdomain} with IP Address #{nextIPADDR} created successfully")
    netmask = netmask(@network)
    set_prov(prov, prov.options[:vm_target_name], nextIPADDR, netmask, @gateway)
  elsif result == false
    $evm.log("info", "GetIP --> #{prov.options[:vm_target_name]}.#{@dnsdomain} with IP Address #{nextIPADDR} FAILED")
  else
    $evm.log("info", "GetIP --> unknown error")
  end


when "getipstatic"
  result = getIP("#{prov.options[:vm_target_name]}.#{@dnsdomain}","#{@staticIP}")
  if result ==  true
    $evm.log("info", "GetIP --> #{prov.options[:vm_target_name]}.#{@dnsdomain} with IP Address #{@staticIP} created successfully")
  elsif result == false
    $evm.log("info", "GetIP --> #{prov.options[:vm_target_name]}.#{@dnsdomain} with IP Address #{@staticIP} FAILED")
  else
    $evm.log("info", "GetIP --> unknown error")
  end


end

$evm.log("info", "********* InfoBlox - GetIP COMPLETED *********")
exit MIQ_OK
