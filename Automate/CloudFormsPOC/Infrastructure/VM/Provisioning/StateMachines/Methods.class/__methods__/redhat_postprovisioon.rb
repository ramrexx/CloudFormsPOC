# redhat_postprovisioon.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method is used to perform post-provisioning customizations for RHEV provisioning
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level,"#{msg}")
    @task.message = msg if @task.respond_to?('message') && update_message
  end

  def dump_root()
    log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    log(:info, "End $evm.root.attributes")
    log(:info, "")
  end

  def retry_method(retry_time, msg='INFO')
    log(:info, "#{msg} - Waiting #{retry_time} seconds}", true)
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  def call_rhevm(provider, uri, type=:get, payload=nil)
    log(:info, "Calling RHEVM URL https://#{provider.ipaddress}#{uri} with type #{type} and payload #{payload rescue "nil"}")
    require 'rest-client'
    require 'json'
    params = {
      :method => type,
      :user => provider.authentication_userid,
      :password => provider.authentication_password,
      :url => "https://#{provider.ipaddress}#{uri}",
      :headers => { :accept => :json, :content_type => :json }
    }
    params[:payload] = JSON.generate(payload) unless payload.nil?
    response = RestClient::Request.new(params).execute
    type == :delete ? (return JSON.parse(response)) : (return {})
  end

  def add_affinity_group(ws_values)
    log(:info, "Processing add_affinity_group", true)
    affinity_uri = prov.options.fetch(:affinity_policy, nil)
    affinity_uri ||= ws_values[:affinity_policy]
    unless @vm.power_state == 'on'
      unless affinity_uri.blank?
        log(:info, "Adding VM to Affinity Policy: #{affinity_uri}", true)
        payload = { :id => "#{@vm.uid_ems}" }
        response = call_rhevm(@vm.ext_management_system, "#{affinity_uri}/vms", :post, payload)
        log(:info, "Response to adding VM: #{@vm.name} to affinity group: #{response.inspect}")
      else
        log(:info, "VM: #{@vm.name} missing affinity group information. Skipping processing...", true)
      end
    else
      log(:info, "VM: #{@vm.name} powered on. Skipping Processing", true)
    end
    log(:info, "Processing add_affinity_group...Complete", true)
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # Get miq_provision from root
  @task = $evm.root['miq_provision']
  log(:info, "Provision: #{@task.id} Request: #{@task.miq_provision_request.id} Type: #{@task.type}")

  @vm = @task.vm
  # ensure that the VM exists
  retry_method(15.seconds, "Waiting for VM: #{@task.get_option(:vm_target_name)}") if @vm.nil?

  ws_values = @task.options.fetch(:ws_values, {})
  log(:info, "WS Values: #{ws_values.inspect}") unless ws_values.blank?
  log(:info, "tags: #{@task.get_tags.inspect}")

  add_affinity_group(ws_values)

  if @vm.power_state == 'off'
    log(:info, "Starting VM, all customizations applied")
    @vm.start
  end

  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[(#{err.class})#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
