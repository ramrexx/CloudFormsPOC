begin

  def log(level, msg)
    $evm.log(level, "SERVICE Inspect: #{msg}")
  end

  def dump_service(service)
    log(:info, "Service:<#{service.name}> Begin Attributes [service.attributes]")
    service.attributes.sort.each { |k, v| log(:info, "Service:<#{service.name}> Attributes - #{k}: #{v.inspect}")}
    log(:info, "Service:<#{service.name}> End Attributes [service.attributes]")
    log(:info, "")

    log(:info, "Service:<#{service.name}> Begin Associations [service.associations]")
    service.associations.sort.each { |assc| log(:info, "Service:<#{service.name}> Associations - #{assc}")}
    log(:info, "Service:<#{service.name}> End Associations [service.associations]")
    log(:info, "")

    log(:info, "Service:<#{service.name}> Begin vms [service.vms]")
    service.vms.sort.each { |vm| log(:info, "Service:<#{service.name}> VM - name:<#{vm.name}> guid:<#{vm.guid}>")}
    log(:info, "Service:<#{service.name}> End vms [service.vms]")
    log(:info, "")

    log(:info, "Service:<#{service.name}> Begin direct_vms [service.direct_vms]")
    service.direct_vms.sort.each { |vm| log(:info, "Service:<#{service.name}> Direct VM - name:<#{vm.name}> guid:<#{vm.guid}>")}
    log(:info, "Service:<#{service.name}> End direct_vms [service.direct_vms]")
    log(:info, "")

    log(:info, "Service:<#{service.name}> Begin indirect_vms [service.indirect_vms]")
    service.indirect_vms.sort.each { |vm| log(:info, "Service:<#{service.name}> Indirect VM - name:<#{vm.name}> guid:<#{vm.guid}>")}
    log(:info, "Service:<#{service.name}> End indirect_vms [service.indirect_vms]")
    log(:info, "")

    log(:info, "Service:<#{service.name}> Begin all_service_children [service.all_service_children]")
    log(:info, "Service:<#{service.name}> All Service Children:<#{service.all_service_children.inspect}>")
    log(:info, "Service:<#{service.name}> End all_service_children [service.all_service_children]")
    log(:info, "")
    
    log(:info, "Service:<#{service.name}> Begin direct_service_children [service.direct_service_children]")
    log(:info, "Service:<#{service.name}> Direct Service Children:<#{service.direct_service_children.inspect}>")
    log(:info, "Service:<#{service.name}> End all_service_children [service.direct_service_children]")
    log(:info, "")

    unless service.tags.nil?
      log(:info, "Service:<#{service.name}> Begin Tags [service.tags]")
      service.tags.sort.each { |tag_element| tag_text = tag_element.split('/'); log(:info, "Service:<#{service.name}> Category:<#{tag_text.first.inspect}> Tag:<#{tag_text.last.inspect}>")}
      log(:info, "Service:<#{service.name}> End Tags [service.tags]")
      log(:info, "")
    end

    log(:info, "Service:<#{service.name}> Begin Virtual Columns [service.virtual_column_names]")
    service.virtual_column_names.sort.each { |vcn| log(:info, "Service:<#{service.name}> Virtual Columns - #{vcn}: #{service.send(vcn)}")} rescue nil
    log(:info, "Service:<#{service.name}> End Virtual Columns [service.virtual_column_names]")
    log(:info, "")
  end


  $evm.vmdb('service').all.select do |service| 
    begin
     dump_service(service)
    rescue => terr
      log(:error, "Error dumping service #{service.name}")
      log(:error, "#{terr} #{terr.backtrace.join("\n")}")
    end
  end
   
  log(:info, "completed successfuly")
  exit MIQ_OK

rescue => err
  log(:error, "#{err}\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
