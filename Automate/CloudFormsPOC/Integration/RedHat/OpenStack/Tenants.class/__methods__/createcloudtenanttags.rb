begin

  def log(level, msg)
    @method = 'createCloudTenantTags'
    $evm.log(level, "#{@method}: #{msg}")
  end

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  # process_tags - Dynamically create categories and tags
  def process_tags( category, category_description, single_value, tag, tag_description )
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.to_s.downcase.gsub(/\W/, '_')
    tag_name = tag.to_s.downcase.gsub(/\W/, '_')
    log(:info, "Converted category name:<#{category_name}> Converted tag name: <#{tag_name}>")
    # if the category exists else create it
    unless $evm.execute('category_exists?', category_name)
      log(:info, "Category <#{category_name}> doesn't exist, creating category")
      $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category_description}")
    end
    # if the tag exists else create it
    unless $evm.execute('tag_exists?', category_name, tag_name)
      log(:info, "Adding new tag <#{tag_name}> description <#{tag_description}> in Category <#{category_name}>")
      $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag_description}")
    end
  end

  log(:info, "Begin Automate Method")

  category = $evm.object['tag_category_name']
  category_description = $evm.object['tag_category_description']

  category = "cloud_tenants" if category.nil?
  category_description = "Cloud Tenants" if category_description.nil?

  list = $evm.vmdb(:cloud_tenant).all
  for item in list
    log(:info, "Cloud Tenant: #{item.inspect}")
    process_tags(category, category_description, false, item.name, item.name)
  end

  log(:info, "End Automate Method")

rescue => err
  log(:error, "#{err} [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
