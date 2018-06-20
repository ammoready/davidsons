require "davidsons/version"

require 'net/ftp'

require 'davidsons/base'
require 'davidsons/user'
require 'davidsons/catalog'
require 'davidsons/inventory'

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

    alias debug? debug

    def initialize
      @debug ||= false
      @ftp_host ||= "ftp.davidsonsinventory.com"
    end
  end

end
