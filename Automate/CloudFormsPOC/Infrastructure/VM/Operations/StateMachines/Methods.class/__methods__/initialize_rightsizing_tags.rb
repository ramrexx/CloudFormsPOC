# initialize_rightsizing_tags.rb
#
# Author: Kevin Morey <kmorey@redhat.com>
# License: GPL v3
#
# Description: This method checks for the existence of the rightsize category and creates tags
#

def process_tags(category, single_value, tag)
  # Convert to lower case and replace all non-word characters with underscores
  category_name = category.to_s.downcase.gsub(/\W/,'_')
  tag_name = tag.to_s.downcase.gsub(/\W/,'_')
  # if the category exists else create it
  unless $evm.execute('category_exists?', category_name)
    $evm.log(:info, "Creating Category: {#{category_name} => #{category}}")
    $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category}")
  end
  # if the tag exists else create it
  unless $evm.execute('tag_exists?', category_name, tag_name)
    $evm.log(:info, "Creating tag: {#{tag_name} => #{tag}}")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag}")
  end
end

category = 'rightsize'
rightsize_tags = ['aggressive', 'moderate', 'conservative']
rightsize_tags.each {|tag| process_tags( category, true, tag ) }
