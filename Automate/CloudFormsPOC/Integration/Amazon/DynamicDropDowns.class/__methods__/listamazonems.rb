# ListAmazonEMS.rb
# 
# Description: List all Amazon Providers
#
begin

  $evm.root.attributes.sort.each { |k, v| $evm.log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}

  amazon_hash = {}

  $evm.vmdb(:ems_amazon).all.each { |ems_amazon|
    amazon_hash["#{ems_amazon.id}"] = "#{ems_amazon.provider_region}"
    $evm.log(:info, "EMS Amazon: #{ems_amazon.name} id: #{ems_amazon.id}")
  }

  amazon_hash[nil] = nil
  $evm.object['values'] = amazon_hash
  $evm.log(:info, "Dropdown Values; #{amazon_hash.inspect}")
  
rescue => err
  (dbtype_hash||={})["#{err.class}: #{err}"] = "#{err.class}: #{err}"
  $evm.object['values'] = dbtype_hash
  $evm.log(:error, "ERROR: Dynamic drop down values: #{$evm.object['values']}")
end
