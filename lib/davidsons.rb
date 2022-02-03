require "davidsons/version"

require 'net/ftp'
require 'smarter_csv'

require 'davidsons/base'
require 'davidsons/user'
require 'davidsons/catalog'
require 'davidsons/inventory'
require 'davidsons/order'

module Davidsons

  class NotAuthenticated < StandardError; end

  class << self
    attr_accessor :config
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield(config)
  end

  class Configuration
    attr_accessor :debug_mode
    attr_accessor :ftp_host
    attr_accessor :proxy_url
    attr_accessor :xmlns

    alias debug_mode? debug_mode

    def initialize
      @debug_mode ||= false
      @ftp_host   ||= "ftp.davidsonsinventory.com"
      @proxy_url  ||= "http://127.0.0.1:8888"
      @xmlns      ||= "https://dealernetwork.davidsonsinc.com/"
    end
  end

end
