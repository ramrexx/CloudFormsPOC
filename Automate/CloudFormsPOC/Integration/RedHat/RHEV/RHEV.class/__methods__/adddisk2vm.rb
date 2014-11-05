###################################
#
# CFME Automate Method: AddDisk2VM
#
# Author: Kevin Morey
#
# Notes: This method adds a disk to a RHEV VM
###################################
begin
  # Method for logging
  def log(level, msg, update_message=false)
    @method = 'AddDisk2VM'
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

  # basic retry logic
  def retry_method(retry_time=1.minute)
    log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  def call_rhev(servername, username, password, action, ref=nil, body_type=:xml, body=nil)
    require 'rest_client'
    require 'xmlsimple'
    require 'json'

    # if ref is a url then use that one instead
    unless ref.nil?
      url = ref if ref.include?('http')
    end
    url ||= "https://#{servername}/#{ref}"

    params = {
      :method=>action,
      :url=>url,
      :user=>username,
      :password=>password,
      :headers=>{ :content_type=>body_type, :accept=>:xml }
    }

    if body_type == :json
      params[:payload] = JSON.generate(body) if body
    else
      params[:payload] = body if body
    end
    log(:info, "Calling -> RHEVM: #{url} action: #{action} payload: #{params[:payload]}")

    response = RestClient::Request.new(params).execute
    #log(:info, "Inspecting -> RHEVM response: #{response.inspect}")
    #log(:info, "Inspecting -> RHEVM headers: #{response.headers.inspect}")
    unless response.code == 200 || response.code == 201 || response.code == 202
      raise "Failure <- RHEVM Response: #{response.code}"
    end
    # use XmlSimple to convert xml to ruby hash
    response_hash = XmlSimple.xml_in(response)
    #log(:info, "Inspecting response_hash: #{response_hash.inspect}")
    return response_hash
  end

  log(:info, "CFME Automate Method Started", true)

  # dump all root attributes to the log
  dump_root()

  case $evm.root['vmdb_object_type']

  when 'miq_provision'
    prov = $evm.root['miq_provision']
    log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

    # get vm object from miq_provision. This assumes that the vm container on the management system is present
    vm = prov.vm
    log(:info, "dest_storage: #{prov.get_option(:dest_storage)}")
    storage_id = prov.get_option(:dest_storage) rescue nil
    storage = $evm.vmdb('storage').find_by_id(storage_id)
    storage_domain_id = storage.ems_ref.match(/.*\/(\w.*)$/)[1]
    log(:info, "Found Storage: #{storage.name} id: #{storage.id} ems_ref: #{storage.ems_ref} storage_domain_id: #{storage_domain_id}")

    disks = []
    if prov.options.has_key?(:ws_values)
      ws_values = prov.options[:ws_values]
      # :ws_values=>{:add_disk1 => '20', :add_disk2=>'50'}
      ws_values.each {|k,v| disks[$1.to_i] = v.to_i if k.to_s =~ /add_disk(\d*)/}
    else
      prov.options.each {|k,v| disks[$1.to_i] = v.to_i if k.to_s =~ /add_disk(\d*)/}
    end
    disks.compact!

  when 'vm'
    # get vm from root
    vm = $evm.root['vm']
    dialog_add_disks_hash = Hash[$evm.root.attributes.sort.collect { |k, v| [k, v] if k.starts_with?('dialog_add_disk') }]
    disks = []
    dialog_add_disks_hash.each {|k,v| disks << v.to_i if k.to_s =~ /dialog_add_disk(\d*)/}

    if vm.storage.blank?
      # For testing purposes you can hardcode storage_domain_id
      storage_domain_id = 'c5301cc1-bead-4248-ada6-aeb69d675390'
    else
      storage_domain_id = vm.storage.ems_ref.match(/.*\/(\w.*)$/)[1]
    end
  end

  unless storage_domain_id.nil? && disks.blank?

    servername = vm.ext_management_system.ipaddress
    username = vm.ext_management_system.authentication_userid
    password = vm.ext_management_system.authentication_password

    # get array_of_current_disks on the vm if they exist
    current_disks_hash = call_rhev(servername, username, password, :get, "#{vm.ems_ref}/disks", :xml, nil)
    if current_disks_hash.blank?
      log(:info, "No disks found for VM: #{vm.name}")
      array_of_current_disks = []
    else
      array_of_current_disks = current_disks_hash['disk']
    end

    # check to see if bootable disk already exists
    array_of_current_disks.each.detect { |disk| disk['bootable'].first =~ (/(true|t|yes|y|1)$/i) } ? bootable = true : bootable = false
    log(:info, "bootable disk exists? #{bootable}")

    # loop through each disk value
    disks.each_with_index do |incoming_disk_size, idx|
      next if incoming_disk_size.zero?
      disk_size_bytes = incoming_disk_size * 1024**3
      log(:info, "Found VM: #{vm.name} vendor: #{vm.vendor.downcase} incoming_disk_size: #{incoming_disk_size} disk_size_bytes: #{disk_size_bytes}")

      # build xml body
      body = "<disk>"
      body += "<storage_domains>"
      body += "<storage_domain id='#{storage_domain_id}'/>"
      body += "</storage_domains>"
      body += "<size>#{disk_size_bytes}</size>"
      body += "<type>system</type>"
      body += "<interface>virtio</interface>"
      body += "<format>cow</format>"
      if bootable
        body += "<bootable>false</bootable>"
      else
        body += "<bootable>true</bootable>"
        bootable = true
      end
      body += "</disk>"
      log(:info, "body: #{body.inspect}")

      log(:info, "Creating #{incoming_disk_size} disk on VM: #{vm.name}", true)
      call_rhev(servername, username, password, :post, "#{vm.ems_ref}/disks", :xml, body)
    end
    log(:info, "Starting VM: #{vm.name}", true)
    vm.start if $evm.root['miq_provision']
  end

  # Exit method
  log(:info, "CFME Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
