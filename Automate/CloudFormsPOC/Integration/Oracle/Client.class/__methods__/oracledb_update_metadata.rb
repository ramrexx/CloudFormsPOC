#
# Update Custom Attributes on VM Object from Oracle Data
#

begin

  def log (level, msg)
    @method = 'OracleDB_Update_Metadata'
    $evm.log(level, "<#{@method}>: #{msg}")
  end

    # process_tags - Dynamically create categories and tags
  def process_tags( category, single_value, tag, tag_description )
    # Convert to lower case and replace all non-word characters with underscores
    category_name = category.to_s.downcase.gsub(/\W/, '_')
    tag_name = tag.to_s.downcase.gsub(/\W/, '_')
    log(:info, "Converted category name:<#{category_name}> Converted tag name: <#{tag_name}>")
    # if the category exists else create it
    unless $evm.execute('category_exists?', category_name)
      log(:info, "Category <#{category_name}> doesn't exist, creating category")
      $evm.execute('category_create', :name => category_name, :single_value => single_value, :description => "#{category}")
    end
    # if the tag exists else create it
    unless $evm.execute('tag_exists?', category_name, tag_name)
      log(:info, "Adding new tag <#{tag_name}> description <#{tag_description}> in Category <#{category_name}>")
      $evm.execute('tag_create', category_name, :name => tag_name, :description => "#{tag_description}")
    end
    return tag_name
  end

  require 'oci8'

  @conn = nil
  log(:info, "Getting object parameters and creating database url")
  log(:info, "EVM Object: #{$evm.object.inspect}")
  oracledb_host = $evm.object['oracledb_host']
  oracledb_port = $evm.object['oracledb_port']
  oracledb_user = $evm.object['oracledb_user']
  oracledb_name = $evm.object['oracledb_name']
  oracledb_password = $evm.object.decrypt('oracledb_password')
  dburl = "//#{oracledb_host}:#{oracledb_port}/#{oracledb_name}"
  log(:info, "Connecting to db with url #{dburl} using #{oracledb_user}/********")

  vm = nil
  case $evm.root['vmdb_object_type']
    when 'vm'
      vm = $evm.root['vm']
      log(:info, "Got vm object from $evm.root['vm']")
    when 'miq_provision'
      vm = $evm.root['miq_provision'].vm
      log(:info, "Got vm object from $evm.root['miq_provision']")
  end
  raise "#{@method} - VM object not found" if vm.nil?
  $evm.log(:info,"VM Found:<#{vm.name}>")

  @conn = OCI8.new(oracledb_user, oracledb_password, dburl)
  log(:info, "Successfully connected to database")

  # Fields to Grab:
  # Business Unit == ORACLE_Business_Unit
  # Project Name == ORACLE_Project_Name
  # Service Name == ORACLE_Service_Name
  # Env Type == ORACLE_Env_Type
  # Env Lifecycle == ORACLE_Env_Lifecycle
  # Security Level == ORACLE_Security_Level
  # Security Zone == ORACLE_Security_Zone
  # Hosting Segment Name == ORACLE_Hosting_Segment_Name
  # Fault Domain Name == ORACLE_Fault_Domain_Name
  # Patch Cycle Name == ORACLE_Patch_Cycle_Name
  # Patch Day == ORACLE_Patch_Day
  # Patch Time == ORACLE_Patch_Time
  select_fields = [
    "BUSINESS_UNIT",
    "PROJECT_NAME",
    "SERVICE_NAME",
    "ENV_TYPE",
    "ENV_LIFECYCLE",
    "SECURITY_LEVEL",
    "SECURITY_ZONE",
    "HOSTING_SEGMENT_NAME",
    "FAULT_DOMAIN_NAME",
    "PATCH_CYCLE_NAME",
    "PATCH_DAY",
    "PATCH_TIME",
    "NAME",
    "CREATED_BY"
  ]
 
  field_tag_mappings = {
    "BUSINESS_UNIT" => "example_bu",
    "SECURITY_ZONE" => "example_sz",
    "HOSTING_SEGMENT_NAME" => "example_hs",
    "FAULT_DOMAIN_NAME" => "example_fd",
    "PROJECT_NAME" => "example_project_name",
    "SECURITY_LEVEL" => "example_security_level"
  }

  sql_statement = "select * from ( select #{select_fields.join(", ")} from ALL_SERVICE_CONTAINERS_VIEW where HOST_NAME = '#{vm.name}' ) where ROWNUM < 2"

  log(:info, "Executing SQL #{sql_statement}")
  @conn.exec(sql_statement).fetch do |row|
    log(:info, "Got response: #{row.join(',')}")
    log(:info, "#{row.inspect}")
    row.each_with_index do |value, index|
      field_val = select_fields[index]
      log(:info, "Set custom attribute ORACLE_#{field_val} to #{value}")
      vm.custom_set("ORACLE_#{field_val}", "#{value}")
      tag_category = field_tag_mappings[field_val]
      value = "NONE" if value == "*"
      value = value.gsub(/Pre-Prod/, "PreProd")
      value = value.gsub(/Non-Public/, "NonPublic")
      value = value.gsub(/ - /, "-")
      unless tag_category.nil?
        log(:info, "Processing tags #{tag_category} #{value}")
        tag_name = process_tags(tag_category, false, value, value)
        log(:info, "Assigning #{tag_category}/#{tag_name} to #{vm.name}")
        vm.tag_assign("#{tag_category}/#{tag_name}")
      end
    end
    vm.tag_assign("oracle_imported/true")
  end

  log(:info, "logging out of oracle connection")
  @conn.logoff
  @con = nil
  log(:info, "exiting automate method")

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
ensure
  unless @conn.nil?
    begin
      @conn.logoff
      puts "Logged off of Oracle"
    rescue => err
    end
  end
end
