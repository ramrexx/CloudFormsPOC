###################################
#
# EVM Automate Method: IPAM_Import
#
# Notes: EVM Automate method to import IPAM .csv file into EVM Automate
#
###################################
begin
  @method = 'IPAM_Import'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  # Turn of verbose logging
  @debug = true


  ############################
  #
  # Method: instance_create
  # Notes: Returns string: true/false
  #
  ############################
  def instance_create(path, hash)
    result = $evm.instance_create(path, hash)
    if result
      $evm.log('info',"Instance: <#{path}> created. Result:<#{result.inspect}>") if @debug
    else
      $evm.log('info',"Instance: <#{path}> not created. Result:<#{result.inspect}>") if @debug
    end
    return result
  end


  ############################
  #
  # Method: instance_exists
  # Notes: Returns string: true/false
  #
  ############################
  def instance_exists(path)
    result = $evm.instance_exists?(path)
    if result
      $evm.log('info',"Instance:<#{path}> exists. Result:<#{result.inspect}>") if @debug
    else
      $evm.log('info',"Instance:<#{path}> does not exist. Result:<#{result.inspect}>") if @debug
    end
    return result
  end


  def import_file(miqpath,fname)
    ####################################################
    # IP Adress Management
    #
    # Specify filename to read
    # File must contain the following construct
    # VLAN       Hostname    IP Address    Subnet Mask Gateway     Inuse
    ############ ########### ############# ########### ########### #########
    # VM Network,myhostname1,10.233.71.169,255.255.255.0,10.233.71.1,true
    # VM Network,myhostname2,10.233.71.170,255.255.255.0,10.233.71.1,false
    #

    raise "File '#{fname}' does not exist" unless File.exist?(fname)

    # Regular Expression to match the following example
    # myhostname1, 10.233.71.0_24, 10.233.71.169,255.255.255.0,10.233.71.1,[used|free]
    regex_line = /^(\w.*),(\w*),(\d*.\d*.\d*.\d*),(\d*.\d*.\d*.\d*),(\d*.\d*.\d*.\d*),(\w*)/i

    # Open file for reading and iterate through the file looking for a match
    file = File.open(fname)
    file.each_line do |line|
      # convert everything to lowercase and strip all leading/trailing whitespaces
      line = line.strip
      $evm.log("info", "Reading line: <#{line}>") if @debug

      # if the regular expression successfully matches else skip the line
      if regex_line =~ line
        hash = {}
        hash['vlan']     = $1
        hash['hostname'] = $2
        hash['ipaddr']   = $3
        hash['submask']  = $4
        hash['gateway']  = $5
        hash['inuse']    = $6

        location = "#{miqpath}/#{hash['ipaddr']}"
        $evm.log("info", "Instance:<#{location}> Hash:<#{hash.inspect}>") if @debug

        # If instance does not already exist
        unless instance_exists(location)
          # Create instance with hash parameters
          instance_create(location, hash)
        else
          $evm.log("info","Instance:<#{location}> already exists") if @debug
        end

      else
        $evm.log("info", "Line: <#{line}> does not match regular expression") if @debug
      end # if regex
    end # file.each do
    file.close
  end


  # Set path to IPAM DB in automate or retrieve from model
  path_to_db = nil
  path_to_db ||= $evm.object['path_to_db']

  # Set full path to import file or retrieve from model
  import_file = nil
  import_file ||= $evm.object['import_file'] || "/var/www/miq/ipamdb.csv"

  # Call import method
  import_file(path_to_db,import_file)

  #
  # Exit method
  #
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
