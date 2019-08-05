module Davidsons
  class Catalog < Base

    WHOLE_CATALOG_FILENAME = 'davidsons_inventory.csv'.freeze
    DEFAULT_SMART_OPTS = {
      chunk_size: 500,
      convert_values_to_numeric: false,
      force_utf8: true,
      key_mapping: {
        "item_#":         :item_identifier,
        item_description: :name,
        upc_code:         :upc,
        manufacturer:     :brand,
        retail_price:     :msrp,
        gun_type:         :category,
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

    def self.all(options = {})
      requires!(options, :username, :password)
      new(options).all
    end

    def all
      tempfile = get_file(WHOLE_CATALOG_FILENAME)
      items    = []

      SmarterCSV.process(tempfile, DEFAULT_SMART_OPTS) do |chunk|
        chunk.each do |item|
          item[:msrp].tr!('$', '')
          item[:upc].tr!('#', '')

          item[:price]      = lowest_price(item)
          item[:mfg_number] = item[:item_identifier]
          item[:quantity]   = item[:quantity].to_i
          item[:features]   = map_features(item)

          item.delete(:sale_ends)
          item.delete(:sale_price)

          items << item
        end
      end

      tempfile.unlink

      items
    end

    protected

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

    def map_features(item)
      {
        finish:         item.delete(:finish),
        barrel_length:  item.delete(:barrel_length),
        overall_length: item.delete(:overall_length),
        model_series:   item.delete(:model_series),
        sights:         item.delete(:sights),
        stock:          item.delete(:stock),
        capacity:       item.delete(:capacity),
      }
    end

  end
end
