# openstack_preprovision.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to apply PreProvision customizations for Openstack provisioning
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level,"#{msg}")
    @task.message = msg if @task.respond_to?('message') && update_message
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  def add_volumes(ws_values, template)
    # add created volumes and add them to the clone_options
    log(:info, "Processing add_volumes...", true)
    volume_hash = @task.options[:volume_hash]
    log(:info, "volume_hash: #{volume_hash.inspect}")

    unless volume_hash.blank?
      volume_array = []
      # pull out boot volume 0 hash for later processing
      boot_volume_size = volume_hash[0][:size].to_i rescue 0
      unless boot_volume_size.zero?
        # add extra volumes to volume_array
        volume_hash.each do |boot_index, volume_options|
          next if volume_options[:uuid].blank?
          (volume_options[:delete_on_termination] =~ (/(false|f|no|n|0)$/i)) ? (delete_on_termination = false) : (delete_on_termination = true)
          log(:info, "Processing boot_index: #{boot_index} - #{volume_options.inspect}")
          if boot_index.zero?
            boot_block_device = { :boot_index => boot_index, :volume_size => '', :source_type => 'volume', :destination_type => 'volume', :uuid => volume_options[:uuid], :delete_on_termination => delete_on_termination }
            log(:info, "volume: #{boot_index} - boot_block_device: #{boot_block_device.inspect}")
            volume_array << boot_block_device
          else
            new_volume = { :boot_index => boot_index, :source_type => 'volume', :destination_type => 'volume', :uuid => volume_options[:uuid], :delete_on_termination => delete_on_termination }
            log(:info, "volume: #{boot_index} - new_volume: #{new_volume.inspect}")
            volume_array << new_volume
          end
        end
        unless volume_array.blank?
          clone_options = @task.get_option(:clone_options) || {}
          clone_options.merge!({ :image_ref => nil, :block_device_mapping_v2 => volume_array })
          @task.set_option(:clone_options, clone_options)
          log(:info, "Provisioning object updated {:clone_options => #{@task.options[:clone_options].inspect}}")
        end
      else
        log(:info, "Boot disk is ephemeral, skipping add_volumes as extra disks if any will be attached during post provisioning")
      end
    end
    log(:info, "Processing add_volumes...Complete", true)
  end

  def add_affinity_group(ws_values)
    # add affinity group id to clone options
    log(:info, "Processing add_affinity_group...", true)
    server_group_id = @task.get_option(:server_group_id) || ws_values[:server_group_id] rescue nil
    unless server_group_id.nil?
      clone_options = @task.get_option(:clone_options) || {}
      clone_options[:os_scheduler_hints] = { :group => "#{server_group_id}" }
      @task.set_option(:clone_options, clone_options)
      log(:info, "Provisioning object updated {:clone_options => #{@task.options[:clone_options].inspect}}")
    end
    log(:info, "Processing add_affinity_group...Complete", true)
  end

  def add_tenant(ws_values)
    # ensure that the tenant is set
    log(:info, "Processing add_tenant...", true)
    if @task.get_option(:cloud_tenant).blank?
      tenant_id   = @task.get_option(:cloud_tenant) || ws_values[:cloud_tenant] rescue nil
      tenant_id ||= @task.get_option(:cloud_tenant_id) || ws_values[:cloud_tenant_id] rescue nil
      unless tenant_id.nil?
        tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_id)
        log(:info, "Using tenant: #{tenant.name} id: #{tenant.id} ems_ref: #{tenant.ems_ref}")
      else
        tenant = $evm.vmdb(:cloud_tenant).find_by_name('admin')
        log(:info, "Using default tenant: #{tenant.name} id: #{tenant.id} ems_ref: #{tenant.ems_ref}")
      end
      @task.set_option(:cloud_tenant, [tenant.id, tenant.name])
      log(:info, "Provisioning object updated {:cloud_tenant => #{@task.options[:cloud_tenant].inspect}}")
    end
    log(:info, "Processing add_tenant...Complete", true)
  end

  def add_networks(ws_values)
    # ensure the cloud_network is set and look for additional networks to add to clone_options
    log(:info, "Processing add_networks...", true)
    cloud_network_id = @task.get_option(:cloud_network) || ws_values[:cloud_network] rescue nil
    cloud_network_id ||= @task.get_option(:cloud_network_id) || ws_values[:cloud_network_id] rescue nil
    unless cloud_network_id.nil?
      cloud_network = $evm.vmdb(:cloud_network).find_by_id(cloud_network_id)
      @task.set_option(:cloud_network, [cloud_network.id, cloud_network.name])
      log(:info, "Provisioning object updated {:cloud_network => #{@task.get_option(:cloud_network).inspect}}")
    end
    network_hash = @task.options[:network_hash]
    log(:info, "network_hash: #{network_hash.inspect}")
    unless network_hash.blank?

    end
    log(:info, "Processing add_networks...Complete", true)
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # Get provisioning object
  @task     = $evm.root['miq_provision']
  log(:info, "Provisioning ID:<#{@task.id}> Provision Request ID:<#{@task.miq_provision_request.id}> Provision Type: <#{@task.provision_type}>")

  template  = @task.vm_template

  # Gets the ws_values
  ws_values = @task.options.fetch(:ws_values, {})

  add_tenant(ws_values)

  add_volumes(ws_values, template)

  # add_affinity_group(ws_values)

  # add_networks(ws_values)

  # Log all of the options to the automation.log
  @task.options.each { |k,v| log(:info, "Provisioning Option Key(#{k.class}): #{k.inspect} Value: #{v.inspect}") }

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
  @task.finished("#{err}") if @task && @task.respond_to?('finished')
  exit MIQ_ABORT
end
