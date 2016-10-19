module PuppetX::Puppetlabs::Transport
  class Winrm
    attr_accessor :winrm
    attr_reader :name

    def initialize(opts)
      @name = opts[:name]
      options = opts[:options] || {}
      @options = options.inject({}){|h, (k, v)| h[k.to_sym] = v; h}

      port = @options.fetch(:port, 5986)
      @connection = @options.fetch(:connection, :ssl)
      @timeout    = @options.fetch(:timeout, 60)
      case @connection
      when :plaintext
        @endpoint = "http://#{opts[:server]}:#{port}/wsman"
        @options[:user] = opts[:username]
        @options[:pass] = opts[:password]
        @options[:disable_sspi] ||= true unless @options[:basic_auth_only]
      when :ssl
        @endpoint = "https://#{opts[:server]}:#{port}/wsman"
        @options[:user] = opts[:username]
        @options[:pass] = opts[:password]
        @options[:disable_sspi] ||= true unless @options[:basic_auth_only]
        @options[:no_ssl_peer_verification] = true
      when :kerberos
        @endpoint = "https://#{opts[:server]}:#{port}/wsman"
      end
    end

    def connect
      Puppet.debug("#{self.class} initializing connection to: #{@endpoint}")

      require 'winrm'
      @winrm ||= WinRM::WinRMWebService.new(
        @endpoint,
        @connection,
        @options
      )
    end

    def powershell(cmd)
      Puppet.debug("Executing on #{@host}:\n#{cmd.gsub(@options[:pass], '*' * @options[:pass].size)}")
      @winrm.create_executor.run_powershell_script(cmd)
    rescue => ex
      if ex.message =~ /Error: Bad HTTP response returned from server \(400\)/i
        Puppet.debug("Error 400 is encountered. This needs to be ignored and command needs to be reexecuted")
        @winrm.create_executor.run_powershell_script(cmd)
      else
        raise ex.message
      end
    end
  end
end
