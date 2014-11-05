begin
  @method = "#{$evm.object}:Openstack_CatalogItemInitialization"

  def log(level, msg)
  	$evm.log(level, "<#{@method}>: #{msg}")
  end

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}") }
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  log(:info, "Automate Method Started")
  dump_root
    # Get the task object from root
  service_template_provision_task = $evm.root['service_template_provision_task']

  # Get destination service object
  service = service_template_provision_task.destination
  log(:info, "Detected Service:<#{service.name}> Id:<#{service.id}> Tasks:<#{service_template_provision_task.miq_request_tasks.count}>")

  # Get dialog options from task
  dialog_options = service_template_provision_task.dialog_options
  log(:info, "Inspecting Dialog Options:<#{dialog_options.inspect}>")

  name = dialog_options.fetch('dialog_instance_name', nil)
  log(:info, "Got dialog_name: #{name}")

  flavor = dialog_options.fetch('dialog_flavor', nil)
  log(:info, "Got Flavor #{flavor}")

  template_name = dialog_options.fetch('dialog_os_type', nil)
  log(:info, "Got OS Type: #{template_name}")

  service_template_provision_task.miq_request_tasks.each do |t|
  	log(:info, " + Child Task: #{t.inspect}")
    t.options.each { |k,v| log(:info, " + --> Child Option: #{k}:#{v}")}
    grandchild_tasks = t.miq_request_tasks
    grandchild_tasks.each do |gc|
      log(:info, " ++ Granchild Task: #{gc.inspect}")
      gc.set_option(:vm_target_name, name)
      gc.set_option(:vm_target_hostname, name)
      # Set flavor to correct flavor for the best fit ems id
      ems_id = gc.get_option(:best_fit_ems_id)
      flavor = $evm.vmdb(:flavor_openstack).all.detect { |flavor_flav| 
      	 log(:info, "Flavor_flav: #{flavor_flav.ems_id}/#{flavor_flav.name} == #{ems_id}/#{flavor}")
         "#{flavor_flav.name}" == "#{flavor}" && "#{flavor_flav.ems_id}" == "#{ems_id}"
      }
      log(:info, "Found flavor: #{flavor.inspect}")
      gc.set_option(:instance_type, [ flavor.id, flavor.name ])

      # set template to correct template from best fit ems id
      template = $evm.vmdb(:template_openstack).all.detect { |templ| 
      	log(:info, "Templ: #{templ.name} #{templ.ems_id} / #{ems_id} #{template_name}")
      	"#{templ.name}" == "#{template_name}" && "#{templ.ems_id}" == "#{ems_id}"
      }
      log(:info, "Found template: #{template.inspect}")
      gc.set_option(:src_vm_id, [ template.id, template.name ])
      openstack = $evm.vmdb(:ems_openstack).all.detect { |ems| "#{ems.id}" == "#{ems_id}" }
      gc.set_option(:src_ems_id, [ openstack.id, openstack.name ])
      gc.options.each { |k,v| log(:info, " ++ --> Granchild Option: #{k}:#{v}}")}
    end
  end
  log(:info, "Automate Method Ended")

  exit MIQ_OK

rescue => err
  log(:error, "ERROR #{err.class}: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
