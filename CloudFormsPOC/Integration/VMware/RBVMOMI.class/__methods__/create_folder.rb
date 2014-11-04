# create_folder.rb
# Kevin Morey
# 2014.04.21
# Notes: This method creates a folder in VMware vCenter and sets the provisoin option :placement_folder_name
#
###################################
begin
  # Method for logging
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
    $evm.root['miq_provision'].message = "#{msg}" if $evm.root['miq_provision'] && update_message
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
    #log(:info, "Sleeping for #{retry_time} seconds")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  # create_vsphere_folder
  def create_vsphere_folder(provider, datacenter, vsphere_folder)
    begin
      require 'rbvmomi'
    rescue LoadError
      log(:error, "gem requirements: gem install rbvmomi")
      return false
    end
    servername = nil || provider.ipaddress
    username = nil || provider.authentication_userid
    password = nil || provider.authentication_password
    credentials = { :host => servername, :user => username, :password => password, :insecure => true }

    log(:info, "Logging in to #{servername}....", true)
    vim = RbVmomi::VIM.connect credentials
    log(:info, "Login successful to #{servername}", true)

    log(:info, "Getting datacenter #{datacenter}")
    dc = vim.serviceInstance.find_datacenter("#{datacenter}")
    log(:info, "Got datacenter: #{dc.inspect}")

    log(:info, "Getting root vm folder")
    root_vm_folder = dc.vmFolder
    log(:info, "Got root_vm_folder: #{root_vm_folder.inspect}")

    log(:info, "Creating folder #{vsphere_folder}", true)
    created_folder = root_vm_folder.traverse("#{vsphere_folder}", RbVmomi::VIM::Folder, true)
    log(:info, "Created Folder #{vsphere_folder} #{created_folder.inspect}", true)
    return true
  end

  log(:info, "CFME Automate Method Started")

  # dump all root attributes to the log
  #dump_root()

  prov = $evm.root['miq_provision']
  log(:info, "Provision: #{prov.id} Request: #{prov.miq_provision_request.id} Type: #{prov.type}")

  vendor = prov.source.vendor.downcase rescue nil
  raise "Invalid vendor detected: #{vendor}" unless vendor == 'vmware'

  template   = prov.vm_template
  provider   = template.ext_management_system
  datacenter = template.v_owning_datacenter
  product    = template.operating_system['product_name'].downcase

  prov_tags = prov.get_tags
  log(:info, "Provision Tags: #{prov_tags.inspect} ")

  log(:info, "Template: #{template.name} Vendor: #{template.vendor} Product: #{product}")

  if template.vendor.downcase == 'vmware'
    user = prov.miq_request.requester
    group = user.miq_group

    # create a folder based on the requesters LDAP group else use the model
    vsphere_folder = "/CloudForms/#{group.description}" || $evm.object['vsphere_folder'] rescue nil

    # uncomment to specify a folder
    #vsphere_folder = "/CFME"

    # uncomment to use a provisioning tag to dynamically create the folder
    # tag = prov_tags[:project]
    # if tag.nil?
    #   vsphere_folder = "/CloudForms/#{tag}"
    # end

    unless vsphere_folder.nil?
      # create new_vsphere_folder_full_path
      new_vsphere_folder_full_path = "#{datacenter}#{vsphere_folder}"
      log(:info, "Looking for path: #{new_vsphere_folder_full_path}")

      path_exists = prov.get_folder_paths.detect do |key, path|
        log(:info, "vSphere folder id: #{key.inspect} => path: #{path.inspect}")
        new_vsphere_folder_full_path == path
      end
      unless path_exists.blank?
        prov.set_option(:placement_folder_name, path_exists)
        log(:info, "Provisioning object :placement_folder_name updated with #{prov.get_option(:placement_folder_name)}")
      else
        result = create_vsphere_folder(provider, datacenter, vsphere_folder)
        if result
          log(:info, "Waiting for folder #{new_vsphere_folder_full_path} to be created", true)
          retry_method()
        else
          log(:warn, "Failed to create folder #{new_vsphere_folder_full_path}")
        end
      end
    end
  else
    log(:info, "Invalid template.vendor: #{template.vendor}")
  end

  # Exit method
  log(:info, "CFME Automate Method Ended")
  exit MIQ_OK

  # Ruby rescue
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  retry_method()
  exit MIQ_STOP
end
