module Davidsons
  class Inventory < Base

    INVENTORY_FILENAME = "davidsons_quantity.csv"
    CHUNK_SIZE         = 1000

    def initialize(options = {})
      requires!(options, :username, :password)

      @options = options
    end

    def self.all(options = {}, &block)
      requires!(options, :username, :password)
      new(options).quantity(&block)
    end

    def self.get_quantity_file(options = {})
      requires!(options, :username, :password)
      new(options).get_quantity_file
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
        key_mapping: { item_number: :item_identifier }
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

    def get_quantity_file
      inventory_tempfile  = get_file(INVENTORY_FILENAME)
      tempfile            = Tempfile.new

      SmarterCSV.process(inventory_tempfile.open, {
        chunk_size: CHUNK_SIZE,
        convert_values_to_numeric: false,
        force_utf8: true,
        key_mapping: {
          item_number:  :item_identifier
        }
      }) do |chunk|
        chunk.each do |item|
          item.except!(:upc_code)

          item[:quantity] = item[:quantity_nc].to_i + item[:quantity_az].to_i

          item.except!(:quantity_nc, :quantity_az)

          tempfile.puts("#{item[:item_number]},#{item[:quantity]}")
        end
      end

      inventory_tempfile.unlink
      tempfile.close

      tempfile.path
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
