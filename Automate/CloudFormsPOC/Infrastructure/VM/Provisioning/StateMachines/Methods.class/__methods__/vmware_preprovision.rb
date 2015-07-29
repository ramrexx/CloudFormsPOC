# vmware_preprovision.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This default method is used to apply PreProvision customizations for VMware
#
def log_and_update_message(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  @task.message = msg if @task && (update_message || level == 'error')
end

def process_customization()
  # Choose the sections to process
  set_vlan          = false
  set_folder        = true
  set_resource_pool = false
  set_notes         = true
  add_disk          = true

  # Get information from the template platform
  template = @task.vm_template
  ems = template.ext_management_system
  product  = template.operating_system['product_name'].downcase
  bitness = template.operating_system['bitness']
  log_and_update_message(:info, "Template:<#{template.name}> Provider:<#{ems.name}> Vendor:<#{template.vendor}> Product:<#{product}> Bitness:<#{bitness}>")

  tags = @task.get_tags
  log_and_update_message(:info, "Provision Tags:<#{tags.inspect}>")

  if set_vlan
    log_and_update_message(:info, "Processing set_vlan...", true)
    ###################################
    # Was a VLAN selected in dialog?
    # If not you can set one here.
    ###################################
    if @task.get_option(:vlan).nil?
      default_vlan = "VM Network"
      #default_dvs = "portgroup1"

      @task.set_vlan(default_vlan)
      #@task.set_dvs(default_dvs)
      log_and_update_message(:info, "Provisioning object <:vlan> updated with <#{@task.get_option(:vlan)}>")
    end
    log_and_update_message(:info, "Processing set_vlan...Complete", true)
  end

  if set_folder
    log_and_update_message(:info, "Processing set_folder...", true)
    ###################################
    # Drop the VM in the targeted folder if no folder was chosen in the dialog
    # The vCenter folder must exist for the VM to be placed correctly else the
    # VM will placed along with the template
    # Folder starts at the Data Center level
    ###################################
    if @task.get_option(:placement_folder_name).nil?
      datacenter = template.v_owning_datacenter
      vsphere_fully_qualified_folder = "#{datacenter}/Discovered virtual machine"

      # @task.get_folder_paths.each { |key, path| log_and_update_message(:info, "Eligible folders:<#{key.inspect}> - <#{path.inspect}>") }
      @task.set_folder(vsphere_fully_qualified_folder)
      log_and_update_message(:info, "Provisioning object <:placement_folder_name> updated with <#{@task.options[:placement_folder_name].inspect}>")
    else
      log_and_update_message(:info, "Placing VM in folder: <#{@task.options[:placement_folder_name].inspect}>")
    end
    log_and_update_message(:info, "Processing set_folder...Complete", true)
  end

  # add_disk - look in ws_values and @task.options for add_disk? parameters
  if add_disk
    log_and_update_message(:info, "Processing add_disk...", true)
    ws_disks = []
    if @task.options.has_key?(:ws_values)
      ws_values = @task.options[:ws_values]
      # :ws_values=>{:add_disk1 => '20', :add_disk2=>'50'}
      ws_values.each {|k,v| ws_disks[$1.to_i] = v.to_i if k.to_s =~ /add_disk(\d*)/}
      ws_disks.compact!
    end
    if ws_disks.blank?
      # @task.options=>{:add_disk1 => '20', :add_disk2=>'50'}
      @task.options.each {|k,v| ws_disks[$1.to_i] = v.to_i if k.to_s =~ /add_disk(\d*)/}
      ws_disks.compact!
    end

    unless ws_disks.blank?
      new_disks = []
      scsi_start_idx = 2

      ws_disks.each_with_index do |size_in_gb, idx|
        next if size_in_gb.zero?
        new_disks << {:bus=>0, :pos=>scsi_start_idx + idx, :sizeInMB=> size_in_gb.gigabytes / 1.megabyte}
      end
      @task.set_option(:disk_scsi, new_disks) unless new_disks.blank?
      log_and_update_message(:info, "Provisioning object <:disk_scsi> updated with <#{@task.get_option(:disk_scsi)}>")
    end
    log_and_update_message(:info, "Processing add_disk...Complete", true)
  end

  if set_resource_pool
    log_and_update_message(:info, "Processing set_resource_pool...", true)
    if @task.get_option(:placement_rp_name).nil?
      ############################################
      # Find and set the Resource Pool for a VM:
      ############################################
      default_resource_pool = 'MyResPool'
      respool = @task.eligible_resource_pools.detect { |c| c.name.casecmp(default_resource_pool) == 0 }
      log_and_update_message(:info, "Provisioning object <:placement_rp_name> updated with <#{respool.name.inspect}>")
      @task.set_resource_pool(respool)
    end
    log_and_update_message(:info, "Processing set_resource_pool...Complete", true)
  end

  if set_notes
    log_and_update_message(:info, "Processing set_notes...", true)
    ###################################
    # Set the VM Description and VM Annotations  as follows:
    # The example would allow user input in provisioning dialog "vm_description"
    # to be added to the VM notes
    ###################################
    # Stamp VM with custom description
    unless @task.get_option(:vm_description).nil?
      vmdescription = @task.get_option(:vm_description)
      @task.set_option(:vm_description, vmdescription)
      log_and_update_message(:info, "Provisioning object <:vmdescription> updated with <#{vmdescription}>")
    end

    # Setup VM Annotations
    vm_notes =  "Owner: #{@task.get_option(:owner_first_name)} #{@task.get_option(:owner_last_name)}"
    vm_notes += "\nEmail: #{@task.get_option(:owner_email)}"
    vm_notes += "\nSource: #{template.name}"
    vm_notes += "\nDescription: #{vmdescription}" unless vmdescription.nil?
    @task.set_vm_notes(vm_notes)
    log_and_update_message(:info, "Provisioning object <:vm_notes> updated with <#{vm_notes}>")
  end
  log_and_update_message(:info, "Processing set_notes...Complete", true)
end

begin
  # Get provisioning object
  @task = $evm.root['miq_provision']
  log_and_update_message(:info, "Provision:<#{@task.id}> Request:<#{@task.miq_request.id}> Type:<#{@task.type}>")

  process_customization

  # Set Ruby rescue behavior
rescue => err
  log_and_update_message(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
