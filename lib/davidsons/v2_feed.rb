require 'csv'
require 'date'

module Davidsons
  # Parses the location-based V2 feeds on the Davidsons SFTP server:
  #
  #   <order location>/V2_Itemspec.csv - catalog and pricing, no quantities
  #   <order location>/V2_Qty.csv      - quantities (UPC, SKU, gQty, pQty, g3Qty)
  #
  # Rows are read by their exact V2 column names and returned with the same keys
  # as the legacy feed, so callers don't need to know which feed they came from.
  class V2Feed

    ITEMSPEC_FILENAME = 'V2_Itemspec.csv'.freeze
    QUANTITY_FILENAME = 'V2_Qty.csv'.freeze

    # Quantity column for each order location's folder. Both use gQty for now;
    # Class 3 stock (g3Qty) isn't included yet.
    QUANTITY_COLUMNS = {
      'FGE' => 'gQty',
      'FPE' => 'gQty',
    }.freeze

    # Sales that aren't running have 0 prices and 1900-01-01 dates
    NO_DATE = Date.new(1900, 1, 1)

    # @param [String] order_location e.g. 'FGE' or 'FPE'
    # @param [Symbol] pricing_tier :regular or :minimum
    # @param [Proc] fetch returns a Tempfile for a filename in the order location's folder
    def initialize(order_location:, pricing_tier:, fetch:, today: Date.today)
      @order_location = order_location
      @pricing_tier   = pricing_tier
      @fetch          = fetch
      @today          = today
      @quantity_column = QUANTITY_COLUMNS.fetch(order_location) do
        raise ArgumentError.new("Unknown Davidsons order location: #{order_location.inspect} (expected one of: #{QUANTITY_COLUMNS.keys.join(', ')})")
      end
    end

    # Used by Catalog.all
    def catalog
      quantities = quantity_by_item_identifier

      each_row(ITEMSPEC_FILENAME).map do |row|
        item_identifier = value(row, 'ItemNo')
        gun_type        = value(row, 'GunType')

        {
          item_identifier: item_identifier,
          upc:             upc(row),
          name:            [value(row, 'ItemDesc1'), value(row, 'ItemDesc2')].reject(&:empty?).join(' '),
          brand:           value(row, 'Brand'),
          mfg_number:      value(row, 'CatNum').empty? ? item_identifier : value(row, 'CatNum'),
          model:           value(row, 'model#'),
          msrp:            value(row, 'RetailPrice'),
          price:           price(row),
          map_price:       value(row, 'MAPPrice'),
          quantity:        quantities[item_identifier].to_i,
          # GunType (e.g. 'Rifle: Semi-Automatic') is what the legacy feed used for
          # category; items without one (ammo, optics, knives...) fall back to Category.
          category:        gun_type.empty? ? value(row, 'Category') : gun_type,
          subcategory:     gun_type.empty? ? value(row, 'Subcategory') : nil,
          product_type:    value(row, 'ItemType'),
          action:          value(row, 'ACTION'),
          caliber:         value(row, 'caliber').empty? ? value(row, 'AmmoCaliber') : value(row, 'caliber'),
          weight:          value(row, 'ShippingWeight'),
          features:        features(row),
        }
      end
    end

    # Used by Inventory.all
    def prices
      quantities = quantity_by_item_identifier

      each_row(ITEMSPEC_FILENAME).map do |row|
        item_identifier = value(row, 'ItemNo')

        {
          item_identifier: item_identifier,
          upc:             upc(row),
          price:           price(row),
          map_price:       value(row, 'MAPPrice'),
          quantity:        quantities[item_identifier].to_i,
        }
      end
    end

    # Used by Inventory.quantity
    def quantities
      each_row(QUANTITY_FILENAME).map do |row|
        {
          item_identifier: value(row, 'SKU'),
          upc:             upc(row),
          quantity:        value(row, @quantity_column).to_i,
          locations: {
            g:  value(row, 'gQty'),
            p:  value(row, 'pQty'),
            g3: value(row, 'g3Qty'),
          },
        }
      end
    end

    private

    def each_row(filename)
      tempfile = @fetch.call(filename)
      CSV.foreach(tempfile.path, headers: true, encoding: 'bom|utf-8').to_a
    ensure
      tempfile&.unlink
    end

    def quantity_by_item_identifier
      quantities.each_with_object({}) do |item, map|
        map[item[:item_identifier]] = item[:quantity]
      end
    end

    def value(row, column)
      row[column].to_s.strip
    end

    # V2 UPCs come without the legacy '#' wrapping; stripped anyway in case it returns
    def upc(row)
      value(row, 'UPC').delete('#')
    end

    # DealerPrice, or MinPrice on the :minimum tier (MinPrice is 0 on many items, so
    # DealerPrice is used then). A sale price only counts while the sale is running
    # and when it's lower.
    def price(row)
      regular = value(row, 'DealerPrice')

      if @pricing_tier.to_s == 'minimum' && value(row, 'MinPrice').to_f > 0
        regular = value(row, 'MinPrice')
      end

      sale = active_sale_price(row)
      sale && sale.to_f < regular.to_f ? sale : regular
    end

    # sale_price and SalePrice carry the same value; sale_price is the one paired
    # with sale_starts/sale_ends.
    def active_sale_price(row)
      sale = value(row, 'sale_price')
      sale = value(row, 'SalePrice') if sale.to_f <= 0
      return if sale.to_f <= 0

      starts = parse_date(value(row, 'sale_starts'))
      ends   = parse_date(value(row, 'sale_ends'))
      return if starts.nil? || ends.nil? || starts == NO_DATE

      sale if starts <= @today && @today <= ends
    end

    def parse_date(text)
      Date.parse(text)
    rescue ArgumentError
      nil
    end

    def features(row)
      {
        finish:         value(row, 'finish'),
        barrel_length:  value(row, 'BarrelLength'),
        overall_length: value(row, 'OverallLength'),
        model_series:   value(row, 'ModelSeries'),
        sight_class:    value(row, 'SightClass'),
        sight_front:    value(row, 'SightFront'),
        sight_rear:     value(row, 'SightRear'),
        stock:          value(row, 'Stock'),
        capacity:       value(row, 'Capacity'),
        image_name:     value(row, 'Image'),
      }
    end

  end
end
