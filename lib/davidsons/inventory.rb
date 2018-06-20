module Davidsons
  class Inventory < Base

    INVENTORY_FILENAME = "davidsons_quantity.csv"

    def initialize(options = {})
      requires!(options, :username, :password)

      @options = options
    end

    def self.quantity(chunk_size = 15, options = {}, &block)
      requires!(options, :username, :password)
      new(options).quantity(chunk_size, &block)
    end

    def quantity(chunk_size, &block)
      tempfile = get_file(INVENTORY_FILENAME)

      SmarterCSV.process(tempfile.open, {
        chunk_size: chunk_size,
        convert_values_to_numeric: false,
        force_utf8: true,
        key_mapping: {
          item_number:  :item_identifier,
          quantity_nc:  :quantity_east,
          quantity_az:  :quantity_west
        }
      }) do |chunk|
        chunk.each do |item|
          item.except!(:upc_code)

          item[:quantity] = item[:quantity_east].to_i + item[:quantity_west].to_i
        end

        yield(chunk)
      end
    end

  end
end
