
begin

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

  # basic retry logic
  def retry_method(retry_time="1.minute")
    log(:info, "Retrying in #{retry_time} seconds")
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = retry_time
    exit MIQ_OK
  end

  service = $evm.root['service']
  raise "Service is nil, cannot continue" if service.nil?

  log(:info, "Got Service: #{service.id} #{service.name}")
  log(:info, "Retiring VMs: #{service.vms.inspect}")

  aws_mgt = nil
  ec2 = nil
  service.vms.each {|vm|
    aws_mgt = vm.ext_management_system
    service.custom_set("MID", "#{aws_mgt.id}")
    ec2 = get_aws_object(aws_mgt)
    begin
      ec2.instances["#{vm.ems_ref}"].disassociate_elastic_ip if service.custom_get("ELASTIC_IPS")
    rescue => ignoreable
      log_err(ignoreable)
    end

    begin
      ec2.instances["#{vm.ems_ref}"].terminate
    rescue => ignoreable
      log_err(ignoreable)
    end
    log(:info, "Terminated #{vm.name}/#{vm.ems_ref}")
    vm.remove_from_vmdb
  }

  if ec2.nil? && service.custom_get("MID")
    begin
      aws_mgt = $evm.vmdb(:ems_amazon).find_by_id(service.custom_get("MID"))
      ec2 = get_aws_object(aws_mgt)
    rescue => err
      log_err(err)
    end
  end
  raise "EC2 Object is NIL, no VMS?" if ec2.nil?

  ec2.elastic_ips.select{ |ip| !ip.associated? }.each(&:release) if service.custom_get("ELASTIC_IPS")

  begin
    ec2.key_pairs["#{service.custom_get("KEYPAIR_NAME")}"].delete
    log(:info, "Deleted key pair #{service.custom_get("KEYPAIR_NAME")}")
  rescue => ignoreable
    log_err(ignoreable)
  end
  sleep 5
  begin
    ec2.security_groups["#{service.custom_get("SECURITY_GROUP")}"].delete
    log(:info, "Deleted security group #{service.custom_get("SECURITY_GROUP")}")
  rescue AWS::EC2::Errors::DependencyViolation => ignoreable
    log_err(ignoreable)
    retry_method("15.seconds")
  end
  
  aws_mgt.refresh
  service.remove_from_vmdb

rescue => err
  log_err(err)
  
  exit MIQ_ABORT
end
