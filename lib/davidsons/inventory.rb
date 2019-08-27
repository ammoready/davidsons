module Davidsons
  class Inventory < Base

    WHOLE_CATALOG_FILENAME = 'davidsons_inventory.csv'.freeze
    DEFAULT_WHOLE_CATALOG_SMART_OPTS = {
      chunk_size: 500,
      convert_values_to_numeric: false,
      force_utf8: true,
      remove_unmapped_keys: true,
      key_mapping: {
        "item_#":     :item_identifier,
        upc_code:     :upc,
        msp:          :msp,
        dealer_price: :dealer_price,
        sale_price:   :sale_price,
        quantity:     :quantity,
      }
    }

    QUANTITY_FILENAME = 'davidsons_quantity.csv'.freeze
    DEFAULT_QUANTITY_SMART_OPTS = {
      chunk_size: 2000,
      convert_values_to_numeric: false,
      force_utf8: true,
      key_mapping: {
        item_number: :item_identifier,
        upc_code:    :upc
      }
    }

    # @param [Hash] options
    # @option options [Symbol] :username *required*
    # @option options [Symbol] :password *required*
    # @option options [Symbol] :pricing_tier *optional*
    #   * Denotes which price to use
    #   * Can be :regular or :minimum
    def initialize(options = {})
      requires!(options, :username, :password)
      @options = options
      @options[:pricing_tier] ||= :regular
    end

    # Iterates over all items in the 'davidsons_inventory.csv' file yielding the item_identifier, quantity, and price.
    # We have to use this file since the 'davidsons_quantity.csv' file does not included prices.
    # The price can vary based on the +pricing_tier+
    #
    # @param [Hash] options
    # @option options [Symbol] :username *required*
    # @option options [Symbol] :password *required*
    # @option options [Symbol] :pricing_tier *optional*
    #   * Denotes which price to use
    #   * Can be :regular or :minimum
    def self.all(options = {})
      requires!(options, :username, :password)
      new(options).all
    end

    # Iterates over all items in the 'davidsons_quantity.csv' file yielding the item_identifier, upc, quantity and locations.
    #
    # @param [Hash] options
    # @option options [Symbol] :username *required*
    # @option options [Symbol] :password *required*
    def self.quantity(options = {})
      requires!(options, :username, :password)
      new(options).quantity
    end

    def all
      items    = []
      tempfile = get_file(WHOLE_CATALOG_FILENAME)

      SmarterCSV.process(tempfile, DEFAULT_WHOLE_CATALOG_SMART_OPTS) do |chunk|
        chunk.each do |item|
          item[:upc].tr!('#', '')

          item[:price]    = lowest_price(item)
          item[:quantity] = item[:quantity].to_i

          items << item
        end
      end

      items
    end

    def quantity
      items    = []
      tempfile = get_file(QUANTITY_FILENAME)

      SmarterCSV.process(tempfile, DEFAULT_QUANTITY_SMART_OPTS) do |chunk|
        chunk.each do |item|
          item[:quantity]  = item[:quantity_nc].to_i + item[:quantity_az].to_i
          item[:locations] = map_location_quantities(item)

          items << item
        end
      end

      items
    end

    private

    def map_location_quantities(item)
      {
        nc: item.delete(:quantity_nc),
        az: item.delete(:quantity_az),
      }
    end

    def lowest_price(item)
      case @options[:pricing_tier]
      when :minimum
        relevant_price = item.delete(:msp).tr('$', '')
        item.delete(:dealer_price)
      else
        relevant_price = item.delete(:dealer_price).tr('$', '')
        item.delete(:msp)
      end

      if item[:sale_price]
        sale_price = item.delete(:sale_price).tr('$', '')
        return sale_price if sale_price.to_f < relevant_price.to_f
      end

      relevant_price
    end

  end
end
