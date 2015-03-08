=begin
 method: uploadimage.rb
 Description: uploads a glance image currently qcow2 to openstack for a specific
 tenant
 and tags it with the correct tenant
 Author: Laurent Domb <laurent@redhat.com>
 License: GPL v3 
-------------------------------------------------------------------------------
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
-------------------------------------------------------------------------------
=end

begin
  require 'securerandom'
  require 'rubygems/package'
  require 'zlib'
  require 'fog'

  def log(level, msg)
    @method = 'UploadImage'
    $evm.log(level, "#{@method}: #{msg}")
  end 

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def parameters_to_hash(parameters)
    log(:info, "Generating hash from #{parameters}")
    array1 = parameters.split(";")
    hash = {}
    for item in array1
      key, value = item.split("=")
      hash["#{key}"] = "#{value}"
    end
    log(:info, "Returning parameter hash: #{hash.inspect}")
    return hash
  end

  def get_tenant
    tenant_ems_id = $evm.root['dialog_cloud_tenant']
    log(:info, "Found EMS ID of tenant from dialog: '#{tenant_ems_id}'")
    return nil if tenant_ems_id.blank?
    tenant = $evm.vmdb(:cloud_tenant).find_by_id(tenant_ems_id)
    log(:info, "Found EMS Object for Tenant from vmdb: #{tenant.inspect}")
    return tenant.name
  end

  log(:info, "Begin Automate Method")

  dump_root
  service_template_provision_task = $evm.root['service_template_provision_task']
  service = service_template_provision_task.destination
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")
  log(:info, "DEBUG: #{service_template_provision_task.inspect}")

  parameters = $evm.root['dialog_parameters']
  image_name = $evm.root['dialog_image_name']
  qcow2_image_url = $evm.root['dialog_image_url']

  image_url = qcow2_image_url
  image_out = File.open("/tmp/#{image_name}", 'wb')

  # Efficient image write
  puts "Downloading Cirros image..."
  streamer = lambda do |chunk, remaining_bytes, total_bytes|
    image_out.write chunk
  end
  Excon.defaults[:ssl_verify_peer] = false
  Excon.get image_url, :response_block => streamer
  image_out.close
  puts "Image downloaded to #{image_out.path}"
  qcow2 = "#{image_out.path}"

  log(:info, "Service Tags: #{service.tags.inspect}")
  tenant = get_tenant
  if tenant.blank?
    tenant = service.tags.select { 
        |tag_element| tag_element.starts_with?("cloud_tenants/")
      }.first.split("/", 2).last rescue nil
    log(:info, "Set tenant to '#{tenant}' because get_tenant returned nothing")
  end
  if tenant.blank?
    tenant = service.custom_get("TENANT_NAME") if tenant.blank?
    log(:info, "Set tenant to '#{tenant}' because couldn't find tenant from tags")
  end

  mid = $evm.root['dialog_mid']
  raise "Management System ID is nil" if mid.blank?

  openstack = $evm.vmdb(:ems_openstack).find_by_id(mid)
  raise "OpenStack Management system with id #{mid} not found" if openstack.nil?
  log(:info, "EMS_Openstack: #{openstack.inspect}\n#{openstack.methods.sort.inspect}")
   
  ### Set tenant
  group = $evm.root['user'].current_group
  provider = $evm.vmdb(:ems_openstack).find_by_id($evm.root['dialog_mid'])
  provider ||= $evm.vmdb(:ems_openstack).all.first
  $evm.log(:info, "inspect provider: #{provider.inspect}")
  
  tenant = group.tags(:tenant_environment).first
  tenant ||= "admin"
  $evm.log(:info, "inspect tenant: #{tenant}")
  ###
  
  log(:info, "Getting Fog Connection to #{openstack[:hostname]}")
  image_service = nil
  begin
    image_service = Fog::Image.new({
      :provider => 'OpenStack',
      :openstack_api_key => openstack.authentication_password,
      :openstack_username => openstack.authentication_userid,
      :openstack_auth_url => "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens",
      :openstack_tenant => tenant
    })
  rescue => connerr
    log(:error, "Retryable connection error #{connerr}")
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = "30.seconds"
    exit MIQ_OK
  end

puts "Uploading Qcow2..."
qcow2 = image_service.images.create :name => image_name,
                                  :size => File.size(qcow2),
                                  :disk_format => 'qcow2',
                                  :container_format => 'bare',
                                  :location => qcow2
File.delete("#{image_out.path}")
provider.refresh

end
