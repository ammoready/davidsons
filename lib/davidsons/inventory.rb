module Davidsons
  class Inventory < Base

    INVENTORY_FILENAME  = "davidsons_quantity.csv"
    CHUNK_SIZE          = 100

    def initialize(options = {})
      requires!(options, :username, :password)

      @options = options
    end

    def self.quantity(options = {}, &block)
      requires!(options, :username, :password)
      new(options).quantity(&block)
    end

    def quantity(&block)
      tempfile = get_file(INVENTORY_FILENAME)

      SmarterCSV.process(tempfile.open, {
        chunk_size: CHUNK_SIZE,
        convert_values_to_numeric: false,
        force_utf8: true,
        key_mapping: {
          item_number:  :item_identifier
        }
      }) do |chunk|
        chunk.each do |item|
          item.except!(:upc_code)

          item[:quantity]   = item[:quantity_nc].to_i + item[:quantity_az].to_i
          item[:locations]  = map_location_quantities(item)

          item.except!(:quantity_nc, :quantity_az)

          yield(item)
        end
      end
    end

    protected

    def map_location_quantities(item)
      {
        nc: item[:quantity_nc],
        az: item[:quantity_az]
      }
    end

  end
end
