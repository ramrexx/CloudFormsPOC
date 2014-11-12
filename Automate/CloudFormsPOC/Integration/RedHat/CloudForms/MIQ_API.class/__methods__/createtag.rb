###################################
#
# EVM Automate Method: createTag
#
# This method is used to create a tag via web service API
#
# Inputs: category, tag, [tag_description]
#
###################################
begin
  @method = 'createTag'
  $evm.log("info", "#{@method} - EVM Automate Method Started")


  ##################################
  #
  # Method: categoryExists
  # Inputs: category
  # Returns: true/false
  #
  ##################################
  def categoryExists?(category)
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.downcase.gsub(/\W/, '_')
    $evm.log("info", "#{@method} - Converted category name:<#{category_name}>") if @debug

    # Double-check Category Creation
    if $evm.execute('category_exists?', category_name)
      $evm.log("info", "#{@method} - Category:<#{category_name}> exists") if @debug
      return true
    else
      return false
    end
  end


  ##################################
  #
  # Method: Create Tag
  # Inputs: category-name, tag-name, [description]
  # Returns: true|false
  #
  ##################################
  def createTag?(category, tag, description=tag)
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.downcase.gsub(/\W/, '_')
    tag_name = tag.downcase.gsub(/\W/, '_')
    $evm.log("info", "#{@method} - Converted category name: <#{category_name}>") if @debug
    $evm.log("info", "#{@method} - Converted tag name: <#{tag_name}>") if @debug


    # if the category does not exist exit
    return false unless categoryExists?(category)

    # if the tag does not exists create it
    unless $evm.execute('tag_exists?', category_name, tag_name)
      $evm.log("info", "#{@method} - Adding new Tag:<#{tag_name}> in Category:<#{category_name}>") if @debug
      $evm.execute('tag_create', category_name, :name => tag_name, :description => description)
    end

    # Double-check Category Creation
    if $evm.execute('tag_exists?', category_name, tag_name)
      $evm.log("info", "#{@method} - Tag:<#{tag_name}> exists in Category:<#{category_name}>") if @debug
      return true
    else
      return false
    end
  end


  # Get required category and tag parameters
  category                = $evm.root['category']
  tag                     = $evm.root['tag']
  # Optional tag parameter - defaults to tag
  tag_description         = $evm.root['tag_description']

  # Exit if either the category or tag is missing from the call
  raise "#{@method} - Category parameter:<#{category}> not specified" if category.nil?
  raise "#{@method} - Tag parameter:<#{tag}> not specified" if tag.nil?

  if createTag?(category, tag, tag_description)
    $evm.log("info","#{@method} - Tag:<#{tag}> creation successful")
  else
    raise "#{@method} - Tag:<#{tag}>  creation failed"
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
