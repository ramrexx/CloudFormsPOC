begin
  require 'io/wait'
  require 'open3'
  require 'tempfile'
  require 'timeout'

  DEFAULT_TIMEOUT = 120
  RAILS_PATH      = '/var/www/miq/vmdb/script/rails'

  def process_pipe(pipe, log_type)
    data = ""
    while pipe && pipe.ready? do
        data << pipe.read
      end
      data.split('\n').each do | line |
        $evm.log(log_type, "Rails output: [#{line}]")
      end
      return data
    end

    def rails_runner(ruby_code)
      output = ""
      errors = ""

      file = File.open("/tmp/seahawks.rb", "w")
      # file = Tempfile.new('ae_rails')
      file.write(ruby_code)
      file.flush
      begin
        begin
          # Wrap in bash to free rails from the bundle environment
          stdin, stdout, stderr, wait_thr =
            Open3.popen3('bash', '-cl', [RAILS_PATH, 'r', file.path].join(' '))
          stdin.close
          Timeout.timeout(DEFAULT_TIMEOUT) do
            begin
              output << process_pipe(stdout, 'info')
              errors << process_pipe(stderr, 'error')
            end until wait_thr.join(1)
            exit MIQ_ABORT if wait_thr.value != 0
          end
        rescue Timeout::Error
          Process.kill('KILL', wait_thr.pid)
          $evm.root['ae_result'] = 'error'
          $evm.root['ae_reason'] = "Timed out waiting for Rails"
          $evm.log('error', $evm.root['ae_reason'])
          exit MIQ_OK
        ensure
          output << process_pipe(stdout, 'info')
          errors << process_pipe(stderr, 'error')
          stdout.close if stdout
          stderr.close if stderr
        end
      ensure
        file.close!
      end
      return output, errors
    end

    rails_ruby_code = <<EOF
    provider = ExtManagementSystem.find_by_id(360000000000001)
    specs = provider.customization_specs
    specs.each do |spec|
      puts \""#{spec.inspect}"\"
    end
EOF

    unless rails_ruby_code.blank?
      $evm.log('info', 'Invoking custom Rails code')
      output, errors = rails_runner(rails_ruby_code)
      $evm.log('info', "Rails result: [stdout: #{output}] [stderr: #{errors}]")
      $evm.object['rails_output'] = output unless output.blank?
      $evm.object['rails_errors'] = errros unless errors.blank?
    end
    exit MIQ_OK

  rescue => err
    $evm.log("error", "Inline Method: <#{@log_prefix}> - [#{err}]\n#{err.backtrace.join("\n")}")
    exit MIQ_ABORT
  end
