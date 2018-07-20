require 'savon'
require 'pp'

module Davidsons
  class Order < Base

    TEST_URL  = 'https://dealernetwork.davidsonsinc.com/testapi/orderservice.asmx?WSDL'
    API_URL   = 'https://dealernetwork.davidsonsinc.com/api/orderservice.asmx?WSDL'

    attr :client

    def initialize(options = {})
      requires!(options, :token, :dealer_number)

      @options = options

      settings = Hash.new
      settings[:wsdl]                     = @options[:test] ? TEST_URL : API_URL
      #settings[:endpoint]                 = @options[:test] ? TEST_URL : API_URL
      #settings[:namespace]                = @options[:test] ? TEST_URL : API_URL
      settings[:env_namespace]            = 'soap'
      #settings[:proxy]                    = Davidsons.config.proxy_url

      if @options[:test]
        settings[:log]              = true
        settings[:log_level]        = :debug
        settings[:pretty_print_xml] = true
      end

      @client = Savon.client(settings)
    end

    def create_order(items, partner_name, partner_phone, purchase_order_number, details = {})
      request = @client.call(:create_order, attributes: { xmlns: Davidsons.config.xmlns }, message: { ':request': {
        ':Token'                => @options[:token],
        ':DealerCustomerNumber' => @options[:dealer_number],
        ':ConsumerName'         => partner_name,
        ':ConsumerPhone'        => partner_phone,
        ':ReferenceNumber'      => purchase_order_number,
        ':Items'                => self.format_items(items),
        ':UseExpeditedShipping' => 'false'
      }})

      order_info = request.body[:create_order_response][:create_order_result]

      if order_info = request.body[:response_code] == "0"
        { success: true, order_number: order_info[:order_number] }
      else
        { success: false, error_code: order_info[:response_code], error_message: order_info[:response_text] }
      end
    end

    def get_order_tracking(order_number)
      request = @client.call(:get_order_tracking, attributes: { xmlns: Davidsons.config.xmlns }, message: { ':request': {
        ':Token'    => @options[:token],
        ':OrderNo'  => order_number 
      }})

      tracking_info = request.body[:get_order_tracking_response][:get_order_tracking_result]

      if tracking_info[:response_code] == "0"
        { success: true, tracking_number: tracking_info[:tracking_number] }
      else
        { success: false, error_code: tracking_info[:response_code], error_message: tracking_info[:response_text] }
      end
    end

    protected

    def format_items(items)
      formatted_items = Array.new

      items.each do |item|
        formatted_items.push({
          ':ItemNumber' => item[:item_identifier],
          ':Quantity'   => item[:quantity]
        })
      end

      { ':ItemRequest' => formatted_items }
    end

    # Invalid Token

  end
end
