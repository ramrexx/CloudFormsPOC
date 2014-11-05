###################################
#
# EVM Automate Method: HPOM_EMS_Cluster_Alert
#
# This method is used to send HPOM Alerts based on Cluster
#
###################################
begin
  @method = 'HPOM_EMS_Cluster_Alert'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true


  ###################################
  #
  # Method: buildDetails
  #
  # Notes: Build email subject and body which map to opcmsg_msg_grp and opcmsg_msg_text
  #
  # Returns: options Hash
  #
  ###################################
  def buildDetails(ems_cluster)

    # Build options Hash
    options = {}

    options[:object] = "Cluster - #{ems_cluster.name}"

    # Set alert to alert description
    options[:alert] = $evm.root['miq_alert_description']

    # Get Appliance name from model unless specified below
    appliance = nil
    #appliance ||= $evm.object['appliance']
    appliance ||= $evm.root['miq_server'].ipaddress

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # Build Email Subject
    subject = "#{options[:alert]} | Cluster: [#{ems_cluster.name}]"
    options[:subject] = subject

    # Build Email Body
    body = "Attention,"
    body += "<br>EVM Appliance: #{$evm.root['miq_server'].hostname}"
    body += "<br>EVM Region: #{$evm.root['miq_server'].region_number}"
    body += "<br>Alert: #{options[:alert]}"
    body += "<br><br>"

    body += "<br>Cluster <b>#{ems_cluster.name}</b> Properties:"
    body += "<br>Cluster URL: <a href='https://#{appliance}/ems_cluster/show/#{ems_cluster.id}'>https://#{appliance}/ems_cluster/show/#{ems_cluster.id}</a>"    
    body += "<br>Total Host CPU Resources: #{ems_cluster.aggregate_cpu_speed}"
    body += "<br>Total Host Memory: #{ems_cluster.aggregate_memory}"
    body += "<br>Total Host CPUs: #{ems_cluster.aggregate_physical_cpus}"
    body += "<br>Total Host CPU Cores: #{ems_cluster.aggregate_logical_cpus}"
    body += "<br>Total Configured VM Memory: #{ems_cluster.aggregate_vm_memory}"
    body += "<br>Total Configured VM CPUs: #{ems_cluster.aggregate_vm_cpus}"
    body += "<br><br>"


    body += "<br>Configuration:"
    body += "<br>HA Enabled: #{ems_cluster.ha_enabled}"
    body += "<br>HA Admit Control: #{ems_cluster.ha_admit_control}"
    body += "<br>DRS Enabled: #{ems_cluster.drs_enabled}"
    body += "<br>DRS Automation Level: #{ems_cluster.drs_automation_level}"
    body += "<br>DRS Migration Threshold: #{ems_cluster.drs_migration_threshold}"
    body += "<br><br>"

    body += "<br>Relationships:"
    body += "<br>Datacenter: #{ems_cluster.v_parent_datacenter}"
    body += "<br>Hosts: #{ems_cluster.total_hosts}"
    body += "<br>VM(s): #{ems_cluster.total_vms}"
    body += "<br><br>"

    body += "<br>Cluster Tags:"
    body += "<br>#{ems_cluster.tags.inspect}"
    body += "<br><br>"

    body += "<br>Regards,"
    body += "<br>#{signature}"
    options[:body] = body

    # Return options Hash with subject, body, alert
    return options
  end


  ###################################
  #
  # Method: boolean
  # Returns: true/false
  #
  ###################################
  def boolean(string)
    return true if string == true || string =~ (/(true|t|yes|y|1)$/i)
    return false if string == false || string.nil? || string =~ (/(false|f|no|n|0)$/i)

    # Return false if string does not match any of the above
    $evm.log("info","#{@method} - Invalid boolean string:<#{string}> detected. Returning false") if @debug
    return false
  end


  ###################################
  #
  # Method: emailStorageAlert
  #
  # Build Alert email
  #
  ###################################
  def emailAlert(options )
    # Get to_email_address from model unless specified below
    to = nil
    to  ||= $evm.object['to_email_address']

    # Get from_email_address from model unless specified below
    from = nil
    from ||= $evm.object['from_email_address']

    # Get subject from options Hash
    subject = options[:subject]

    # Get body from options Hash
    body = options[:body]

    $evm.log("info", "#{@method} - Sending email To:<#{to}> From:<#{from}> subject:<#{subject}>") if @debug
    $evm.execute(:send_email, to, from, subject, body)
  end


  ###################################
  #
  # Method: call_opcmsg
  #
  # Notes: Run opcmsg to send an event to HP Operations Manager
  #
  ###################################
  def call_opcmsg(options)
    opcmsg_path = "/opt/OV/bin/opcmsg"
    raise "#{@method} - File '#{opcmsg_path}' does not exist" unless File.exist?(opcmsg_path)
    $evm.log("info","#{@method} - Found opcmsg_path:<#{opcmsg_path}>") if @debug

    cmd  = "#{opcmsg_path}"
    cmd += " application=\"#{$evm.object['opcmsg_application']}\""
    cmd += " object=\"#{options[:object]}\""
    cmd += " msg_text=\"#{options[:body]}\""
    cmd += " severity=\"#{$evm.object['opcmsg_severity']}\""
    cmd += " msg_grp=\"#{options[:alert]}\""

    $evm.log("info","#{@method} - Calling:<#{cmd}>") if @debug
    require 'open4'
    pid = nil
    stderr = nil
    results = Open4.popen4(cmd) do |pid, stdin, stdout, stderr|
      stderr.each_line { |msg| $evm.log("error","#{@method} - Method STDERR:<#{msg.strip}>") }
      stdout.each_line { |msg| $evm.log("info","#{@method} - Method STDOUT:<#{msg.strip}>") }
    end
    $evm.log("info","#{@method} - Inspecting Results:<#{results.inspect}>") if @debug
  end


  ems_cluster = $evm.root['ems_cluster']

  unless ems_cluster.nil?
    $evm.log("info", "#{@method} - Detected Cluster:<#{ems_cluster.name}>") if @debug

    # If email is set to true in the model
    options = buildDetails(ems_cluster)

    # Get email from model
    email = $evm.object['email']

    if boolean(email)
      emailAlert(options)
    end

    call_opcmsg(options)
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
