module Davidsons
  class Catalog < Base

    CATALOG_FILENAME = "davidsons_inventory.csv".freeze
    CHUNK_SIZE       = 100

    def initialize(options = {})
      requires!(options, :username, :password)

      @options = options
    end

    def self.all(options = {}, &block)
      requires!(options, :username, :password)
      new(options).all(&block)
    end

    def all(&block)
      tempfile = get_file(CATALOG_FILENAME)

      SmarterCSV.process(tempfile.open, {
        chunk_size: CHUNK_SIZE,
        convert_values_to_numeric: false,
        force_utf8: true,
        key_mapping: {
          "item_#":         :item_identifier,
          item_description: :name,
          upc_code:         :upc,
          manufacturer:     :brand,
          msp:              :msrp,
          dealer_price:     :price,
          gun_type:         :category,
        }
      }) do |chunk|
        chunk.each do |item|
          item.except!(:retail_price, :capacity, :sale_price, :sale_ends)

          item[:msrp].tr!('$', '')
          item[:price].tr!('$', '')
          item[:upc].tr!('#', '')

          item[:mfg_number] = item[:item_identifier]
          item[:quantity] = item[:quantity].to_i
          item[:features] = map_features(item)

          yield(item)
        end
      end
    end

    protected

    def map_features(item)
      {
        finish:         item.delete(:finish),
        barrel_length:  item.delete(:barrel_length),
        overall_length: item.delete(:overall_length),
        model_series:   item.delete(:model_series),
        sights:         item.delete(:sights),
        stock:          item.delete(:stock),
      }
    end

  end
end
