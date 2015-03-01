begin

  def log(level, msg)
    @method = 'listHeatTemplates'
    $evm.log(level, "#{@method}: #{msg}")
  end

  list = $evm.vmdb(:customization_template).all
  log(:info, "Got list #{list.inspect}")
  my_hash = {}
  for ct in list
    if ct.name.start_with?("HEAT-")
      my_hash[ct.id] = ct.description
      log(:info, "Pushed #{ct.name} onto the list")
    else
      log(:info, "Not pushing #{ct.name} onto the list")
    end
  end

  my_hash[nil] = nil

  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = my_hash
  log(:info, "Dynamic drop down values: #{$evm.object['values']}")

rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
