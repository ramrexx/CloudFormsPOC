
begin

  @task = nil
  @service = nil

  # Simple logging method
  def log(level, msg)
    $evm.log(level, msg)
  end

  # Error logging convenience
  def log_err(err)
    log(:error, "#{err.class} #{err}")
    log(:error, "#{err.backtrace.join("\n")}")
  end

  # standard dump of $evm.root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  def get_aws_object(ext_mgt_system, type="EC2")
    require 'aws-sdk'
    AWS.config(
      :access_key_id => ext_mgt_system.authentication_userid,
      :secret_access_key => ext_mgt_system.authentication_password,
      :region => ext_mgt_system.provider_region
      )
    return Object::const_get("AWS").const_get("#{type}").new()
  end

    # Get the AWS Management System from teh various options available
  def get_mgt_system()
    aws_mgt = nil
    if @task
      if @task.get_option(:provider_id)
        aws_mgt = $evm.vmdb(:ems_amazon).find_by_id(@task.get_option(:provider_id))
        log(:info, "Got AWS Mgt System from @task.get_option(:provider_id)")
      end
    elsif $evm.root['vm']
      vm = $evm.root['vm']
      aws_mgt = vm.ext_management_system
      log(:info, "Got AWS Mgt System from VM #{vm.name}")
    else
      aws_mgt = $evm.vmdb(:ems_amazon).first
      log(:info, "Got First Available AWS Mgt System from VMDB")
    end
    return aws_mgt
  end

  log(:info, "Begin Automate Method")

  dump_root
 
  # Get the task object from root
  @task = $evm.root['service_template_provision_task']
  if @task
    # List Service Task Attributes
    @task.attributes.sort.each { |k, v| log(:info, "#{@method} - Task:<#{@task}> Attributes - #{k}: #{v}")}

    # Get destination service object
    @service = @task.destination
    log(:info,"Detected Service:<#{@service.name}> Id:<#{@service.id}>")
  end

  require 'aws-sdk'

  # get the AWS Management System Object
  aws_mgt = get_mgt_system
  log(:info, "AWS Mgt System is #{aws_mgt.inspect}")

  ec2 = get_aws_object(aws_mgt)
  log(:info, "Got EC2 Object: #{ec2.inspect}")

  vpc = ec2.vpcs.first
  log(:info, "Deploying to VPC #{vpc.id} #{vpc.cidr_block}")

  tcp_ports = $evm.object['tcp_ports']
  tcp_source_cidr = $evm.object['tcp_source_cidr']
  tcp_source_cidr ||= "0.0.0.0/0"

  security_group = nil
  if tcp_ports
    log(:info, "Enabling TCP Ports: #{tcp_ports} from cidr #{tcp_source_cidr}")
    security_group ||= ec2.security_groups.create("#{@task.get_option(:class_name)}-#{rand(36**3).to_s(36)}", 
                                                  { :vpc => vpc.id, :description => "Sec Group for #{@task.get_option(:class_name)}" })
    port_array = tcp_ports.split(',')
    port_array.each { |port|
      security_group.authorize_ingress(:tcp, port.to_i, tcp_source_cidr)
      log(:info, "Enabled ingress on tcp port #{port.to_i} from #{tcp_source_cidr}")
    }
  end

  udp_ports = $evm.object['udp_ports']
  udp_source_cidr = $evm.object['udp_source_cidr']
  udp_source_cidr ||= "0.0.0.0/0"

  if udp_ports
    log(:info, "Enabling UDP Ports #{udp_ports} from cidr #{udp_source_cidr}")
    security_group ||= ec2.security_groups.create("#{@task.get_option(:class_name)}-#{rand(36**3).to_s(36)}")
    port_array = udp_ports.split(',')
    port_array.each { |port|
      security_group.authorize_ingress(:udp, port.to_i, udp_source_cidr)
      log(:info, "Enabled ingress on udp port #{port.to_i} from #{udp_source_cidr}")
    }
  end

  @service.custom_set("SECURITY_GROUP", "#{security_group.id}")

  log(:info, "Exit Automate Method")

rescue => err
  log_err(err)
  $evm.root['ae_result'] = "error"
  @task.message = "Error Provisioning AWS Security: #{err.class} '#{err}'"
  @service.remove_from_vmdb if @service && @task && @task.get_option(:remove_from_vmdb_on_fail)
  exit MIQ_ABORT
end
