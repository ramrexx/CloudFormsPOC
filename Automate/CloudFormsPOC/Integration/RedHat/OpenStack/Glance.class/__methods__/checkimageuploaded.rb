=begin
 method: checkimageuploaded.rb
 Description: checks if the glance image is visible to cloudforms
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

def log(level, msg, update_message=false)
  $evm.log(level,"#{msg}")
  $evm.root['service_template_provision_task'].message = msg if $evm.root['service_template_provision_task'] && update_message
end

  group = $evm.root['user'].current_group  
  tenant = group.tags(:tenant_environment).first
  tenant ||= "admin"
  $evm.log(:info, "inspect tenant: #{tenant}")

# basic retry logic
def retry_method(retry_time, msg)
  log(:info, "#{msg} - Waiting #{retry_time} seconds}", true)
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

image_name = $evm.root['dialog_image_name']

image = $evm.vmdb(:miq_template).find_by_name(image_name)

retry_method(10.seconds, "Image Status: #{image}") unless image != nil

image.tag_assign("tenant_environment/#{tenant}")
