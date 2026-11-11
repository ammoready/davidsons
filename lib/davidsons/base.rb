module Davidsons
  class Base

    SFTP_PROTOCOL     = 'sftp'.freeze
    DEFAULT_SFTP_PORT = 22

    # Opens a connection and yields it: a Net::FTP for the legacy FTP server, or a
    # Net::SFTP::Session when +protocol: 'sftp'+ is passed (the location-based V2 feeds).
    #
    # @param [Hash] options
    # @option options [String] :username *required*
    # @option options [String] :password *required*
    # @option options [String] :ftp_host *optional*
    #   * Server to connect to. Defaults to Davidsons.config.ftp_host.
    # @option options [String] :protocol *optional*
    #   * 'sftp' to connect over SFTP. Defaults to FTP.
    # @option options [Integer] :port *optional*
    #   * SFTP port. Defaults to 22.
    def self.connect(options = {})
      requires!(options, :username, :password)

      if sftp?(options)
        connect_sftp(options) { |sftp| yield sftp }
      else
        connect_ftp(options) { |ftp| yield ftp }
      end
    end

    # Per-call :ftp_host wins over the global config, so accounts on different
    # Davidsons servers can be used side by side.
    def self.ftp_host(options = {})
      host = options[:ftp_host].to_s.strip
      host.empty? ? Davidsons.config.ftp_host : host
    end

    def self.sftp?(options = {})
      options[:protocol].to_s.strip.downcase == SFTP_PROTOCOL
    end

    def self.connect_ftp(options)
      Net::FTP.open(ftp_host(options), options[:username], options[:password]) do |ftp|
        ftp.passive = true
        ftp.debug_mode = Davidsons.config.debug_mode?

        yield ftp
      end
    rescue Net::FTPPermError => e
      if e.to_s.start_with?('530')
        raise Davidsons::NotAuthenticated
      else
        raise e
      end
    end

    # Net::SFTP.start always returns nil when given a block (unlike Net::FTP.open),
    # so the block's result is captured and returned explicitly.
    def self.connect_sftp(options)
      port   = (options[:port] || DEFAULT_SFTP_PORT).to_i
      result = nil

      Net::SFTP.start(ftp_host(options), options[:username], password: options[:password], port: port, non_interactive: true) do |sftp|
        result = yield sftp
      end

      result
    rescue Net::SSH::AuthenticationFailed
      raise Davidsons::NotAuthenticated
    end

    protected

    # Wrapper to `self.requires!` that can be used as an instance method.
    def requires!(*args)
      self.class.requires!(*args)
    end

    def self.requires!(hash, *params)
      params.each do |param|
        if param.is_a?(Array)
          raise ArgumentError.new("Missing required parameter: #{param.first}") unless hash.has_key?(param.first)

          valid_options = param[1..-1]
          raise ArgumentError.new("Parameter: #{param.first} must be one of: #{valid_options.join(', ')}") unless valid_options.include?(hash[param.first])
        else
          raise ArgumentError.new("Missing required parameter: #{param}") unless hash.has_key?(param)
        end
      end
    end

    # Instance methods become class methods through inheritance
    def connect(options)
      self.class.connect(options) do |ftp|
        yield ftp
      end
    end

    # Location-based (V2) feeds are read when an :order_location is passed, e.g. 'FGE'.
    def v2?
      !order_location.empty?
    end

    def order_location
      @options[:order_location].to_s.strip.upcase
    end

    # V2 feeds live in a folder named after the order location, e.g. FGE/V2_Qty.csv
    def remote_path(filename)
      v2? ? "#{order_location}/#{filename}" : filename
    end

    def v2_feed
      @v2_feed ||= V2Feed.new(
        order_location: order_location,
        pricing_tier:   @options[:pricing_tier],
        fetch:          ->(filename) { get_file(filename) }
      )
    end

    def get_file(filename)
      path = remote_path(filename)

      connect(@options) do |conn|
        tempfile = Tempfile.new

        if self.class.sftp?(@options)
          conn.download!(path, tempfile.path)
        else
          conn.getbinaryfile(path, tempfile.path)
        end

        tempfile
      end
    end

  end
end
