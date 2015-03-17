# list_amazon_keypairs.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: List all Amazon kay pairs
#
begin
  def log(level, msg, update_message=false)
    $evm.log(level, "#{msg}")
  end

  def dump_root()
    $evm.log(:info, "Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "\t Attribute: #{k} = #{v}")}
    $evm.log(:info, "End $evm.root.attributes")
    $evm.log(:info, "")
  end

  def get_provider(provider_id=nil)
    $evm.root.attributes.detect { |k,v| provider_id = v if k.end_with?('provider_id') } rescue nil
    provider = $evm.vmdb(:ems_amazon).find_by_id(provider_id)
    log(:info, "Found provider: #{provider.name} via provider_id: #{provider.id}") if provider

    # set to true to default to the fist amazon provider
    use_default = false
    unless provider
      # default the provider to first openstack provider
      provider = $evm.vmdb(:ems_amazon).first if use_default
      log(:info, "Found amazon: #{provider.name} via default method") if provider && use_default
    end
    provider ? (return provider) : (return nil)
  end

  def query_catalogitem(option_key)
    # use this method to query a catalogitem
    # note that this only works for items not bundles since we do not know which item within a bundle(s) to query from
    option_value = nil
    service_template = $evm.root['service_template']
    unless service_template.nil?
      if service_template.service_type == 'atomic'
        log(:info, "Catalog item: #{service_template.name}")
        service_template.service_resources.each do |catalog_item|
          catalog_item_resource = catalog_item.resource
          if catalog_item_resource.respond_to?('get_option')
            option_value = catalog_item_resource.get_option(option_key)
          else
            option_value = catalog_item_resource[option_key] rescue nil
          end
          log(:info, "Found {#{option_key} => #{option_value}}") if option_value
        end
      else
        log(:info, "Catalog bundle: #{service_template.name} found, skipping query")
      end
    end
    option_value ? (return option_value) : (return nil)
  end

  ###############
  # Start Method
  ###############
  log(:info, "CloudForms Automate Method Started", true)
  dump_root()

  # check the catalogitem for a provider id
  provider_id = query_catalogitem(:src_ems_id)
  log(:info, "Found provider_id: #{provider_id}") if provider_id

  # see if provider is already set in root
  provider = get_provider(provider_id)

  dialog_hash = {}

  if provider
    $evm.vmdb(:auth_key_pair_amazon).all.each do |kp|
      next unless kp.resource_id == provider.id 
      dialog_hash[kp.id] = "#{kp.name} on #{provider.name}"
    end
  else
    # no provider so list everything
    $evm.vmdb(:auth_key_pair_amazon).all.each do |kp|
      provider = $evm.vmdb(:ems_amazon).find_by_id(kp.resource_id)
      dialog_hash[kp.id] = "#{kp.name} on #{provider.name}"
    end
  end

  if dialog_hash.blank?
    dialog_hash[nil] = "< No Key Pairs Found, Contact Administrator >"
  else
    #$evm.object['default_value'] = dialog_hash.first
    dialog_hash[nil] = '< choose a key pair >'
  end

  $evm.object['values'] = dialog_hash
  log(:info, "$evm.object['values']: #{$evm.object['values'].inspect}")
  
  ###############
  # Exit Method
  ###############
  log(:info, "CloudForms Automate Method Ended", true)
  exit MIQ_OK

  # Set Ruby rescue behavior
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
