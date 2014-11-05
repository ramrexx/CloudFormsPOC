begin

  def log(level, msg)
    @method = 'listOpenstackEMS'
    $evm.log(level, "#{@method}: #{msg}")
  end

  openstack_hash = {}

  list = $evm.vmdb(:ems_openstack).all
  for item in list
    openstack_hash[item.name] = item.id
  end

  openstack_hash[nil] = nil

  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = openstack_hash
  log(:info, "Dynamic drop down values: #{$evm.object['values']}")

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
