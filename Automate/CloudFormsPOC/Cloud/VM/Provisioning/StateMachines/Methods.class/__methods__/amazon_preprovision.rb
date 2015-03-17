# amazon_preprovision.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to apply PreProvision customizations for Amazon provisioning
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

  def add_security_groups()
    # ensure that the security group is set
    log(:info, "Processing add_security_groups...", true)
    ws_values = @task.options.fetch(:ws_values, {})
    if @task.get_option(:security_groups).blank?
      security_group_id   = @task.get_option(:security_groups) || ws_values[:security_groups] rescue nil
      security_group_id ||= @task.get_option(:security_groups_id) || ws_values[:security_groups_id] rescue nil
      unless security_group_id.nil?
        security_group = $evm.vmdb(:security_group).find_by_id(security_group_id)
      end
      if security_group
        log(:info, "Using security_group: #{security_group.name} id: #{security_group.id} ems_ref: #{security_group.ems_ref}")
        @task.set_option(:security_groups, [security_group.id, security_group.name])
        log(:info, "Provisioning object updated {:security_group => #{@task.options[:security_groups].inspect}}")
      end
    end
    log(:info, "Processing add_security_groups...Complete", true)
  end

  def add_key_pair()
    # ensure that the key_pair is set
    log(:info, "Processing add_key_pair...", true)
    ws_values = @task.options.fetch(:ws_values, {})
    if @task.get_option(:guest_access_key_pair).blank?
      key_pair_id   = @task.get_option(:guest_access_key_pair) || ws_values[:guest_access_key_pair] rescue nil
      key_pair_id ||= @task.get_option(:guest_access_key_pair_id) || ws_values[:guest_access_key_pair_id] rescue nil
      key_pair_id ||= @task.get_option(:key_pair) || ws_values[:key_pair_id] rescue nil
      unless key_pair_id.nil?
        key_pair = $evm.vmdb(:auth_key_pair_amazon).find_by_id(key_pair_id) || $evm.vmdb(:auth_key_pair_amazon).find_by_name(key_pair_id)
      end
      if key_pair
        log(:info, "Using key_pair: #{key_pair.name} id: #{key_pair.id} ems_ref: #{key_pair.ems_ref}")
        @task.set_option(:guest_access_key_pair, [key_pair.id, key_pair.name])
        log(:info, "Provisioning object updated {:guest_access_key_pair => #{@task.options[:guest_access_key_pair].inspect}}")
      end
    end
    log(:info, "Processing add_key_pair...Complete", true)
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # Get provisioning object
  @task     = $evm.root['miq_provision']
  log(:info, "Provisioning ID:<#{@task.id}> Provision Request ID:<#{@task.miq_provision_request.id}> Provision Type: <#{@task.provision_type}>")

  @template  = @task.vm_template
  @provider  = @template.ext_management_system

  add_security_groups()
  add_key_pair()

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
