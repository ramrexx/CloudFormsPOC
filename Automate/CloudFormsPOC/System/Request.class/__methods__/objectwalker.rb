#
# objectWalker
#
# Can be called from anywhere in the CloudForms / ManageIQ automation namespace, and will walk the automation object structure starting from $evm.root
# and dump (to automation.log) its attributes, any objects found, their attributes, virtual columns, and associations, and so on.
#
# Author:   Peter McGowan (pemcg@redhat.com)
#           Copyright 2014 Peter McGowan, Red Hat
#
# Revision History
#
# Original      1.0     18-Sep-2014
#               1.1     22-Sep-2014     Added blacklisting/whitelisting to the walk_association functionality
#               1.2     24-Sep-2014     Changed exception handling logic slightly
#   
@method = 'objectWalker'
VERSION = 1.2
#
# Change MAX_RECURSION_LEVEL to adjust the depth of recursion that objectWalker traverses through the objects
#
MAX_RECURSION_LEVEL = 7
@recursion_level = 0
@object_recorder = {}
#
# @print_nil_values can be used to toggle whether or not to include keys that have a nil value in the
# output dump. There are often many, and including them will usually increase verbosity, but it is
# sometimes useful to know that a key/attribute exists, even if it currently has no assigned value.
#
@print_nil_values = false
@debug = false
#
# @walk_association_policy should have the value of either :whitelist or :blacklist. This will determine whether we either 
# walk all associations _except_ those in the @walk_association_blacklist hash, or _only_ the associations in the
# @walk_association_whitelist hash
#
@walk_association_policy = :blacklist
#
# if @walk_association_policy = :whitelist, then objectWalker will only traverse associations of objects that are explicitly
# mentioned in the @walk_association_whitelist hash. This enables us to carefully control what is dumped. If objectWalker finds
# an association that isn't in the hash, it will print a line similar to:
#
# $evm.root['vm'].datacenter (type: Association, objects found)
#   (datacenter isn't in the @walk_associations hash for MiqAeServiceVmRedhat...)
#
# If you wish to explore and dump this associaiton, edit the hash to add the association name to the list associated with the object type. The symbol
# :ALL can be used to walk all associations of an object type
#
@walk_association_whitelist = { "MiqAeServiceServiceTemplateProvisionTask" => ["source", "destination", "miq_request", "miq_request_tasks", "service_resource"],
                                "MiqAeServiceServiceTemplate" => ["service_resources"],
                                "MiqAeServiceServiceResource" => ["resource", "service_template"],
                                "MiqAeServiceMiqProvisionRequest" => ["miq_request", "miq_request_tasks"],
                                "MiqAeServiceMiqProvisionRequestTemplate" => ["miq_request", "miq_request_tasks"],
                                "MiqAeServiceMiqProvisionVmware" => ["source", "destination", "miq_provision_request", "miq_request", "miq_request_task", "vm"],
                                "MiqAeServiceMiqProvisionRedhat" => [:ALL],
                                "MiqAeServiceMiqProvisionRedhatViaPxe" => [:ALL],
                                "MiqAeServiceVmVmware" => ["ems_cluster", "ems_folder", "resource_pool", "ext_management_system", "storage", "service", "hardware"],
                                "MiqAeServiceVmRedhat" => ["ems_cluster", "ems_folder", "resource_pool", "ext_management_system", "storage", "service", "hardware"],
                                "MiqAeServiceHardware" => ["nics"]}
#
# if @walk_association_policy = :blacklist, then objectWalker will traverse all associations of all objects, except those
# that are explicitly mentioned in the @walk_association_blacklist hash. This enables us to run a more exploratory dump, at the cost of a
# much more verbose output. The symbol:ALL can be used to prevent the walking any associations of an object type
#
@walk_association_blacklist = { "MiqAeServiceEmsCluster" => ["all_vms", "vms", "ems_events"],
                                "MiqAeServiceEmsRedhat" => ["ems_events"],
                                "MiqAeServiceHostRedhat" => ["guest_applications", "ems_events"]}


$evm.log("info", "#{@method} #{VERSION} - EVM Automate Method Started")

#-------------------------------------------------------------------------------------------------------------
# Method:       dump_attributes
# Purpose:      Dump the attributes of an object
# Arguments:    object_string : 
#               this_object
#               spaces
# Returns:      None
#-------------------------------------------------------------------------------------------------------------
def dump_attributes(object_string, this_object, spaces)
  begin
    #
    # Print the attributes of this object
    #
    if this_object.respond_to?(:attributes)
      $evm.log("info", "#{spaces}#{@method}:   Debug: this_object.inspected = #{this_object.inspect}") if @debug
      this_object.attributes.sort.each do |key, value|
        if key != "options"
          if value.is_a?(DRb::DRbObject)
            $evm.log("info", "#{spaces}#{@method}:   #{object_string}[\'#{key}\'] => #{value}   (type: #{value.class})")
            dump_object("#{object_string}[\'#{key}\']", value, spaces)
          else
            if value.nil?
              $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{key} = nil") if @print_nil_values
            else
              $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{key} = #{value}   (type: #{value.class})")
            end
          end
        else
          value.sort.each do |k,v|
            if v.nil?
              $evm.log("info", "#{spaces}#{@method}:   #{object_string}.options[:#{k}] = nil") if @print_nil_values
            else
              $evm.log("info", "#{spaces}#{@method}:   #{object_string}.options[:#{k}] = #{v}   (type: #{v.class})")
            end
          end
        end
      end
    else
      $evm.log("info", "#{spaces}#{@method}:   This object has no attributes")
    end
  rescue => err
    $evm.log("error", "#{@method} (dump_attributes) - [#{err}]\n#{err.backtrace.join("\n")}")
    exit MIQ_ABORT
  end
end

# End of dump_attributes
#-------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Method:       dump_virtual_columns
# Purpose:      Dumps the virtual_columns_names of the object passed to it
# Arguments:    object_string : friendly text string name for the object
#               this_object   : the Ruby object whose virtual_column_names are to be dumped
#               spaces        : the number of spaces to indent the output (corresponds to recursion depth)
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def dump_virtual_columns(object_string, this_object, spaces)
  begin
    #
    # Print the virtual columns of this object 
    #
    if this_object.respond_to?(:virtual_column_names)
      $evm.log("info", "#{spaces}#{@method}:   --- virtual columns follow ---")
      this_object.virtual_column_names.sort.each do |virtual_column_name|
        virtual_column_value = this_object.send(virtual_column_name)
        if virtual_column_value.nil?
          $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{virtual_column_name} = nil") if @print_nil_values
        else
          $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{virtual_column_name} = #{virtual_column_value}   (type: #{virtual_column_value.class})")
        end
      end
      $evm.log("info", "#{spaces}#{@method}:   --- end of virtual columns ---")
    end
  rescue => err
    $evm.log("error", "#{@method} (dump_virtual_columns) - [#{err}]\n#{err.backtrace.join("\n")}")
    exit MIQ_ABORT
  end
end

# End of dump_virtual_columns
#-------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Method:       dump_association
# Purpose:      Dumps the association of the object passed to it
# Arguments:    object_string       : friendly text string name for the object
#               association         : friendly text string name for the association
#               associated_objects  : the list of objects in the association
#               spaces              : the number of spaces to indent the output (corresponds to recursion depth)
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def dump_association(object_string, association, associated_objects, spaces)
  begin
    #
    # Assemble some fake code to make it look like we're iterating though associations (plural)
    #
    number_of_associated_objects = associated_objects.length
    if (association =~ /.*s$/)
      assignment_string = "#{object_string}.#{association}.each do |#{association.chop}|"
    else
      assignment_string = "#{association} = #{object_string}.#{association}"
    end
    $evm.log("info", "#{spaces}#{@method}:   #{assignment_string}")
    associated_objects.each do |associated_object|
      associated_object_class = "#{associated_object.method_missing(:class)}".demodulize
      associated_object_id = associated_object.id rescue associated_object.object_id
      $evm.log("info", "#{spaces}|    #{@method}:   (object type: #{associated_object_class}, object ID: #{associated_object_id})")
      if (association =~ /.*s$/)
        dump_object("#{association.chop}", associated_object, spaces)
        if number_of_associated_objects > 1
          $evm.log("info", "#{spaces}#{@method}:  --- next #{association.chop} ---")
          number_of_associated_objects -= 1
        else
          $evm.log("info", "#{spaces}#{@method}:  --- end of #{object_string}.#{association}.each do |#{association.chop}| ---")
        end
      else
        dump_object("#{association}", associated_object, spaces)
      end
    end
  rescue => err
    $evm.log("error", "#{@method} (dump_association) - [#{err}]\n#{err.backtrace.join("\n")}")
    exit MIQ_ABORT
  end
end

# End of dump_association
#-------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Method:       dump_associations
# Purpose:      Dumps the associations (if any) of the object passed to it
# Arguments:    object_string     : friendly text string name for the object
#               this_object       : the Ruby object whose associations are to be dumped
#               this_object_class : the class of the object whose associations are to be dumped
#               spaces            : the number of spaces to indent the output (corresponds to recursion depth)
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def dump_associations(object_string, this_object, this_object_class, spaces)
  #
  # Print the associations of this object according to the @walk_associations_whitelist & @walk_associations_blacklist hashes
  #
  object_associations = []
  associated_objects = []
  if this_object.respond_to?(:associations)
    $evm.log("info", "#{spaces}#{@method}:   --- associations follow ---")
    object_associations = Array(this_object.associations)
    object_associations.sort.each do |association|
      begin
        associated_objects = Array(this_object.send(association))
        if associated_objects.length == 0
          $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{association} (type: Association (empty))")
        else
          $evm.log("info", "#{spaces}#{@method}:   #{object_string}.#{association} (type: Association)")
          #
          # See if we need to walk this association according to the @walk_association_policy variable, and the @walk_association_{whitelist,clacklist} hashes
          #
          if @walk_association_policy == :whitelist
            if @walk_association_whitelist.has_key?(this_object_class) &&
                (@walk_association_whitelist[this_object_class].include?(:ALL) || @walk_association_whitelist[this_object_class].include?(association.to_s))
              dump_association(object_string, association, associated_objects, spaces)
            else
              $evm.log("info", "#{spaces}#{@method}:     (#{association} isn't in the @walk_association_whitelist hash for #{this_object_class} and so has not been walked...)")
            end
          elsif @walk_association_policy == :blacklist
            if @walk_association_blacklist.has_key?(this_object_class) &&
                (@walk_association_blacklist[this_object_class].include?(:ALL) || @walk_association_blacklist[this_object_class].include?(association.to_s))
              $evm.log("info", "#{spaces}#{@method}:     (#{association} is in the @walk_association_blacklist hash for #{this_object_class} and so has not been walked...)")
            else
              dump_association(object_string, association, associated_objects, spaces)
            end
          else
            $evm.log("info", "#{spaces}#{@method}:     Invalid @walk_association_policy: #{@walk_association_policy}")
            exit MIQ_ABORT
          end
        end
      rescue NoMethodError
        $evm.log("info", "#{spaces}#{@method}:     #{this_object_class} claims to have an association of \'#{association}\', but this gives a NoMethodError when accessed")
      rescue => err
        $evm.log("error", "#{@method} (dump_associations) - [#{err}]\n#{err.backtrace.join("\n")}")
        exit MIQ_ABORT
      end
    end
    $evm.log("info", "#{spaces}#{@method}:   --- end of associations ---")
  else
    $evm.log("info", "#{spaces}#{@method}:   This object has no associations")
  end
end

# End of dump_associations
#-------------------------------------------------------------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------
# Method:       dump_object
# Purpose:      Dumps the object passed to it
# Arguments:    object_string : friendly text string name for the object
#               this_object   : the Ruby object to be dumped
#               spaces        : the number of spaces to indent the output (corresponds to recursion depth)
# Returns:      None
#-------------------------------------------------------------------------------------------------------------

def dump_object(object_string, this_object, spaces)
  begin
    if @recursion_level == 0
      spaces += "     "
    else
      spaces += "|    "
    end
    #
    # Make sure that we don't exceed our maximum recursion level
    #
    @recursion_level += 1
    if @recursion_level > MAX_RECURSION_LEVEL
      $evm.log("info", "#{spaces}#{@method}:   Exceeded maximum recursion level")
      @recursion_level -= 1
      return
    end
    #
    # Make sure we haven't dumped this object already (some data structure links are cyclical)
    #
    this_object_id = this_object.id.to_s rescue this_object.object_id.to_s
    $evm.log("info", "#{spaces}#{@method}:   Debug: this_object.method_missing(:class) = #{this_object.method_missing(:class)}}") if @debug
    this_object_class = "#{this_object.method_missing(:class)}".demodulize
    $evm.log("info", "#{spaces}#{@method}:   Debug: this_object_class = #{this_object_class}") if @debug
    if @object_recorder.key?(this_object_class)
      if @object_recorder[this_object_class].include?(this_object_id)
        $evm.log("info", "#{spaces}#{@method}:   Object #{this_object_class} with ID #{this_object_id} has already been dumped...")
        @recursion_level -= 1
        return
      else
        @object_recorder[this_object_class] << this_object_id
      end
    else
      @object_recorder[this_object_class] = []
      @object_recorder[this_object_class] << this_object_id
    end
    
    $evm.log("info", "#{spaces}#{@method}:   Dumping $evm.root") if @recursion_level == 1
    #
    # Dump out the things of interest
    #
    dump_attributes(object_string, this_object, spaces)
    dump_virtual_columns(object_string, this_object, spaces)
    dump_associations(object_string, this_object, this_object_class, spaces)
  
    @recursion_level -= 1
  rescue => err
    $evm.log("error", "#{@method} (dump_object) - [#{err}]\n#{err.backtrace.join("\n")}")
    exit MIQ_ABORT
  end
end

# End of dump_object
#-------------------------------------------------------------------------------------------------------------

#
# Start with the root object
#
dump_object("$evm.root", $evm.root, "")
#
# Exit method
#
$evm.log("info", "#{@method} - EVM Automate Method Ended")
exit MIQ_OK
