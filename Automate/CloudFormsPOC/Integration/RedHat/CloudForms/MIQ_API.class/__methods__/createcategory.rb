###################################
#
# EVM Automate Method: createCategory
#
# This method is used to create a tag category via web service API
#
# Inputs: category, [single_value=true|false category_description]
#
###################################
begin
  @method = 'createCategory'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Debug logging mode
  @debug = true

  ##################################
  #
  # Method: Create Tag Category
  # Inputs: category-name, [single_value=[true|false], description]
  # Returns: true/false
  #
  ##################################
  def createCategory?(category, single_value=true, description=category)
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.downcase.gsub(/\W/, '_')
    $evm.log("info", "#{@method} - Converted category name: <#{category_name}>") if @debug

    # if the category does not exist create it
    unless $evm.execute('category_exists?', category_name)
      $evm.log("info", "#{@method} - Category:<#{category_name}> doesn't exist, creating category") if @debug
      $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => description)
    end

    # Double-check Category Creation
    if $evm.execute('category_exists?', category_name)
      $evm.log("info", "#{@method} - Category:<#{category_name}> exists") if @debug
      return true
    else
      return false
    end
  end


  # Get category
  category                = $evm.root['category']
  # Optional category parameters
  single_value            = $evm.root['single_value']
  category_description    = $evm.root['category_description']

  # Exit if either the category or tag is missing from the call
  raise "#{@method} - Category parameter:<#{category}> not specified" if category.nil?

  unless createCategory?(category, single_value, category_description)
    raise "#{@method} - Could not create category:<#{category}>"
  end


  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
