module Davidsons
  class Base

    def self.connect(options = {})
      requires!(options, :username, :password)

      Net::FTP.open(Davidsons.config.ftp_host, options[:username], options[:password]) do |ftp|
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

    def get_file(filename)
      connect(@options) do |ftp|
        begin
          tempfile = Tempfile.new

          ftp.getbinaryfile(filename, tempfile.path)

          tempfile.close

          tempfile
        ensure
          ftp.close
        end
      end
    end

  end
end
