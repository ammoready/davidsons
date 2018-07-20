require "davidsons/version"

require 'net/ftp'

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
    attr_accessor :debug
    attr_accessor :ftp_host
    attr_accessor :proxy_url
    attr_accessor :xmlns

    alias debug? debug

    def initialize
      @debug      ||= false
      @ftp_host   ||= "ftp.davidsonsinventory.com"
      @proxy_url  ||= "http://172.31.69.148:8888"
      @xmlns      ||= "https://dealernetwork.davidsonsinc.com/"
    end
  end

end
