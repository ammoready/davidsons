module Davidsons
  class User < Base

    def initialize(options = {})
      requires!(options, :username, :password)

      @options = options
    end

    def authenticated?
      connect(@options) { |ftp| ftp.pwd }
      true
    rescue Davidsons::NotAuthenticated => e
      puts "Davidsons::User#authenticated? => false"
      puts e
      false
    end

  end
end
