require 'net/ssh'
require 'net/sftp'
require 'tempfile'
require 'active_support/core_ext/object/blank'

module ManageIQ
  class SSH
    # Utility wrapper around the net-ssh library.
    class Util
      # The exit status of the ssh command.
      attr_reader :status

      # The name of the host provided to the constructor.
      attr_reader :host

      # The options hash passed to the constructor.
      attr_reader :options

      # The username passed to the constructor.
      attr_reader :user

      # Create and return a ManageIQ::SSH::Util object. A host, user and
      # password must be specified.
      #
      # The +options+ param may contain options that are passed directly
      # to the Net::SSH constructor. By default the :non_interactive option is
      # set to true (meaning it will fail instead of prompting for a password),
      # the :verbose level is set to :warn, and the :use_agent option is
      # set to false.
      #
      # The :logger option is not set by default. If you do set it, you should
      # NOT use an existing logger, but instead use a separate custom log.
      # If the log already exists, then the option is effectively ignored. Some
      # additional logging will be written to the global ManageIQ log in
      # debug mode.
      #
      # The following local options are also supported:
      #
      # :passwordless_sudo - If set to true, then it is assumed that the sudo
      # command does not require a password, and 'sudo' will automatically be
      # prepended to your command. For sudo that requires a password, set
      # the :su_user and :su_password options instead.
      #
      # :remember_host - Setting this to true will cause a HostKeyMismatch
      # error to be rescued and retried once after recording the host and
      # key in the known hosts file. By default this is false.
      #
      # :su_user - If set, ssh commands for that object will be executed via
      # sudo. Do not use if :passwordless_sudo is set to true.
      #
      # :su_password - When used in conjunction with :su_user, the password sent
      # to the command prompt when asked for as the result of using the su
      # command. Do not use if :passwordless_sudo is set to true.
      #
      def initialize(host, user, password = nil, options = {})
        @host     = host
        @user     = user
        @password = password

        @options  = {
          :remember_host   => false,
          :verbose         => :warn,
          :non_interactive => true,
          :use_agent       => false
        }.merge(options)

        @options[:password] = password if password

        # Pull our custom keys out of the hash because the SSH initializer will complain
        @remember_host     = @options.delete(:remember_host)
        @su_user           = @options.delete(:su_user)
        @su_password       = @options.delete(:su_password)
        @passwordless_sudo = @options.delete(:passwordless_sudo)

        # Obsolete, delete if passed in
        @options.delete(:authentication_prompt_delay)
      end

      # Returns a boolean value indicating whether or not the +remember_host+
      # option is set. This tells Net::SSH to record the host and key in the
      # known hosts file, so that subsequent connections will remember them.
      #
      def remember_host?
        !!@remember_host
      end

      # Download the contents of the remote +from+ file to the local +to+ file. Some
      # messages will be written to the global ManageIQ log in debug mode.
      #
      # Note that the returned data is normally a Net::SFTP::Operations::Download
      # object. If you want to store the file contents in memory, pass an IO object
      # as the second argument.
      #
      def get_file(from, to)
        run_session do |ssh|
          $log&.debug("#{self.class}##{__method__} - Copying file #{host}:#{from} to #{to}.")
          data = ssh.sftp.download!(from, to)
          $log&.debug("#{self.class}##{__method__} - Copying of #{host}:#{from} to #{to}, complete.")
          return data
        end
      end

      # Upload the contents of local file +to+ to remote location +path+. You may
      # use the specified +content+ instead of the content of the local file.
      #
      # At least one of the +content+ or +path+ parameters must be specified or
      # an error is raised.
      #
      def put_file(to, content = nil, path = nil)
        raise ArgumentError, "Need to provide either content or path" if content.nil? && path.nil?
        run_session do |ssh|
          content ||= IO.binread(path)
          $log&.debug("#{self.class}##{__method__} - Copying file to #{@host}:#{to}.")
          ssh.sftp.file.open(to, 'wb') { |f| f.write(content) }
          $log&.debug("#{self.class}##{__method__} - Copying of file to #{@host}:#{to}, complete.")
        end
      end

      # Execute the remote +cmd+ via ssh. This is automatically handled via
      # channels on the ssh session so that various states can be checked,
      # stored and logged independently and asynchronously.
      #
      # If the :passwordless_sudo option was set to true in the constructor
      # then the +cmd+ will automatically be prepended with "sudo".
      #
      # If specified, the data collection will stop the first time a +done_string+
      # argument is encountered at the end of a line. In practice you would
      # typically specify a newline character.
      #
      # If present, the +stdin+ argument will be sent to the underlying
      # command as input for those commands that expect it, e.g. tee.
      #
      # If a signal is received, the command returns any sort of non-zero
      # error status, or if any stderr output is encountered then an exception
      # is raised.
      #
      def exec(cmd, done_string = nil, stdin = nil)
        error_buffer = ""
        output_buffer = ""
        status = 0
        signal = nil
        header = "#{self.class}##{__method__}"

        # If passwordless sudo is true then prepend every command with 'sudo'.
        cmd = 'sudo ' + cmd if @passwordless_sudo

        run_session do |ssh|
          ssh.open_channel do |channel|
            channel.exec(cmd) do |chan, success|
              raise "#{header} - Could not execute command #{cmd}" unless success

              $log&.debug("#{header} - Command: #{cmd} started.")

              if stdin.present?
                chan.send_data(stdin)
                chan.eof!
              end

              channel.on_data do |_channel, data|
                $log&.debug("#{header} - STDOUT: #{data}")
                output_buffer << data
                data.each_line { |l| return output_buffer if done_string == l.chomp } unless done_string.nil?
              end

              channel.on_extended_data do |_channel, _type, data|
                $log&.debug("#{header} - STDERR: #{data}")
                error_buffer << data
              end

              channel.on_request('exit-status') do |_channel, data|
                status = data.read_long || 0
                $log&.debug("#{header} - STATUS: #{status}")
              end

              channel.on_request('exit-signal') do |_channel, data|
                signal = data.read_string
                $log&.debug("#{header} - SIGNAL: #{signal}")
              end

              channel.on_eof do |_channel|
                $log&.debug("#{header} - EOF RECEIVED")
              end

              channel.on_close do |_channel|
                $log&.debug("#{header} - Command: #{cmd}, exit status: #{status}")
                if signal.present? || status.nonzero? || error_buffer.present?
                  raise "#{header} - Command '#{cmd}' exited with signal #{signal}" if signal.present?
                  raise "#{header} - Command '#{cmd}' exited with status #{status}" if status.nonzero?
                  raise "#{header} - Command '#{cmd}' failed: #{error_buffer}"
                end
                return output_buffer
              end
            end # exec
          end # open_channel
          ssh.loop
        end # run_session
      end

      # Execute the remote +cmd+ via ssh. This is nearly identical to the exec
      # method, and is used only if the :su_user and :su_password options are
      # set in the constructor.
      #
      # The difference between this method and the exec method are primarily in
      # the underlying handling of the sudo user and sudo password parameters, i.e
      # creating a PTY session and dealing with prompts. From the perspective of
      # an end user they are essentially identical.
      #
      def suexec(cmd_str, done_string = nil, stdin = nil)
        error_buffer = ""
        output_buffer = ""
        prompt = ""
        cmd_rx = ""
        status = 0
        signal = nil
        state  = :initial
        header = "#{self.class}##{__method__}"

        run_session do |ssh|
          temp_cmd_file(cmd_str) do |cmd|
            ssh.open_channel do |channel|
              # now we request a "pty" (i.e. interactive) session so we can send data back and forth if needed.
              # it WILL NOT WORK without this, and it has to be done before any call to exec.
              channel.request_pty(:chars_wide => 256) do |_channel, success|
                raise "Could not obtain pty (i.e. an interactive ssh session)" unless success
              end

              channel.on_data do |channel, data|
                $log&.debug("#{header} - state: [#{state.inspect}] STDOUT: [#{data.hex_dump.chomp}]")
                if state == :prompt
                  # Detect the common prompts
                  # someuser@somehost ... $  rootuser@somehost ... #  [someuser@somehost ...] $  [rootuser@somehost ...] #
                  prompt = data if data =~ /^\[*[\w\-\.]+@[\w\-\.]+.+\]*[\#\$]\s*$/
                  output_buffer << data
                  unless done_string.nil?
                    data.each_line { |l| return output_buffer if done_string == l.chomp }
                  end

                  if output_buffer[-prompt.length, prompt.length] == prompt
                    return output_buffer[0..(output_buffer.length - prompt.length)]
                  end
                end

                if state == :command_sent
                  cmd_rx << data
                  state = :prompt if cmd_rx == "#{cmd}\r\n"
                end

                if state == :password_sent
                  prompt << data.lstrip
                  if data.strip =~ /\#/
                    $log&.debug("#{header} - Superuser Prompt detected: sending command #{cmd}")
                    channel.send_data("#{cmd}\n")
                    state = :command_sent
                  end
                end

                if state == :initial
                  prompt << data.lstrip
                  if data.strip =~ /[Pp]assword:/
                    prompt = ""
                    $log&.debug("#{header} - Password Prompt detected: sending su password")
                    channel.send_data("#{@su_password}\n")
                    state = :password_sent
                  end
                end
              end

              channel.on_extended_data do |_channel, _type, data|
                $log&.debug("#{header} - STDERR: #{data}")
                error_buffer << data
              end

              channel.on_request('exit-status') do |_channel, data|
                status = data.read_long
                $log&.debug("#{header} - STATUS: #{status}")
              end

              channel.on_request('exit-signal') do |_channel, data|
                signal = data.read_string
                $log&.debug("#{header} - SIGNAL: #{signal}")
              end

              channel.on_eof do |_channel|
                $log&.debug("#{header} - EOF RECEIVED")
              end

              channel.on_close do |_channel|
                error_buffer << prompt if [:initial, :password_sent].include?(state)
                $log&.debug("#{header} - Command: #{cmd}, exit status: #{status}")
                raise "#{header} - Command #{cmd}, exited with signal #{signal}" unless signal.nil?
                unless status.zero?
                  raise "#{header} - Command #{cmd}, exited with status #{status}" if error_buffer.empty?
                  raise "#{header} - Command #{cmd} failed: #{error_buffer}, status: #{status}"
                end
                return output_buffer
              end

              $log&.debug("#{header} - Command: [#{cmd_str}] started.")
              su_command = @su_user == 'root' ? "su -l\n" : "su -l #{@su_user}\n"

              channel.exec(su_command) do |chan, success|
                raise "#{header} - Could not execute command #{cmd}" unless success
                if stdin.present?
                  chan.send_data(stdin)
                  chan.eof!
                end
              end
            end
          end
          ssh.loop
        end
      end

      # Creates a local temporary file under /var/tmp with +cmd+ as its contents.
      # The tempfile name is the name of the command with "miq-" prepended and ".sh"
      # appended to the end.
      #
      # The end result is a string meant to be run via the suexec method. For example:
      #
      # "chmod 700 /var/tmp/miq-foo.sh; /var/tmp/miq-foo.sh; rm -f /var/tmp/miq-foo.sh
      #
      def temp_cmd_file(cmd)
        temp_remote_script = Tempfile.new(["miq-", ".sh"], "/var/tmp")
        temp_file          = temp_remote_script.path
        begin
          temp_remote_script.write(cmd)
          temp_remote_script.close
          remote_cmd = "chmod 700 #{temp_file}; #{temp_file}; rm -f #{temp_file}"
          yield(remote_cmd)
        ensure
          temp_remote_script.close!
        end
      end

      # Shortcut method that creates and yields a ManageIQ::SSH::Util object, with the +host+,
      # +remote_user+ and +remote_password+ options passed in as the first three
      # params to the constructor, while the +su_user+ and +su_password+ parameters
      # automatically set the corresponding :su_user and :su_password options. The
      # remaining options are passed normally.
      #
      # This method is functionally identical to the following code, except that it
      # yields itself (and nil).
      #
      #   ManageIQ::SSH::Util.new(host, remote_user, remote_password, {:su_user => su_user, :su_password => su_password})
      #
      def self.shell_with_su(host, remote_user, remote_password, su_user, su_password, options = {})
        options[:su_user], options[:su_password] = su_user, su_password
        ssu = new(host, remote_user, remote_password, options)
        yield(ssu, nil)
      end

      # Executes the provided +cmd+ using the exec or suexec method, depending on
      # whether or not the :su_user option is set. The +done_string+ and +stdin+
      # arguments are passed along to the appropriate method as well.
      #
      # In the case of suexec, escape characters are automatically removed from
      # the final output.
      #
      #--
      # The _shell argument appears to be an artifact that has been retained
      # over time for reasons that aren't immediately apparent.
      #
      def shell_exec(cmd, done_string = nil, _shell = nil, stdin = nil)
        return exec(cmd, done_string, stdin) if @su_user.nil?
        ret = suexec(cmd, done_string, stdin)
        # Remove escape character from the end of the line
        ret.sub!(/\e$/, '')
        ret
      end

      # Copies the remote +file_path+ to a local temporary file, and then
      # yields or returns a filehandle to the local temporary file.
      #--
      # Presumably this method was meant for use with the SCVMM provider
      # given the hardcoded name of the temporary file.
      #
      def file_open(file_path, perm = 'r')
        if block_given?
          Tempfile.open('miqscvmm') do |tf|
            tf.close
            get_file(file_path, tf.path)
            File.open(tf.path, perm) { |f| yield(f) }
          end
        else
          tf = Tempfile.open('miqscvmm')
          tf.close
          get_file(file_path, tf.path)
          File.open(tf.path, perm)
        end
      end

      # Returns whether or not the remote +filename+ exists.
      #
      def file_exists?(filename)
        shell_exec("test -f #{filename}")
      rescue
        false
      else
        true
      end

      # This method creates and yields an ssh object. If the :remember_host option
      # was set to true, it will record this host and key in the known hosts file
      # and retry once.
      #
      def run_session
        first_try = true

        begin
          Net::SSH.start(@host, @user, @options) do |ssh|
            yield(ssh)
          end
        rescue Net::SSH::HostKeyMismatch => err
          if remember_host? && first_try
            # Save fingerprint and try again
            first_try = false
            err.remember_host!
            retry
          else
            # Re-raise error
            raise err
          end
        end
      end
    end # Util
  end # SSH
end # ManageIQ
