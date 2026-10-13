require 'spec_helper'

# Fixtures in spec/fixtures/v2 are real rows from the FGE feed (file dated 2026-10-07):
#   00856  POF rifle - sale 1515.00 running 2026-07-29..2026-12-31, gQty 0 / pQty 1
#   00004  Case knife - sale 25.99 ended 2026-08-31, MinPrice 0, gQty 20 / pQty 0
#   171102 Leupold rings - no sale, MinPrice 64.00 < DealerPrice 67.69, gQty 4 / pQty 5
#   04959  ATM ammo - no sale, no GunType, gQty 0 / pQty 0
RSpec.describe 'Davidsons V2 feeds' do

  let(:credentials) {{ username: 'usr', password: 'psw', ftp_host: 'ftp.davidsons.com', protocol: 'sftp', port: 22 }}
  let(:fge)         { credentials.merge(order_location: 'FGE') }
  let(:fpe)         { credentials.merge(order_location: 'FPE') }

  def fixture_copy(filename)
    tempfile = Tempfile.new(['v2', '.csv'])
    FileUtils.copy_file(File.join(Dir.pwd, 'spec', 'fixtures', 'v2', filename), tempfile.path)
    tempfile
  end

  before do
    allow(Date).to receive(:today).and_return(Date.new(2026, 10, 7))
    allow_any_instance_of(Davidsons::Base).to receive(:get_file) { |_, filename| fixture_copy(filename) }
  end

  def by_id(items)
    items.each_with_object({}) { |item, map| map[item[:item_identifier]] = item }
  end

  describe 'remote paths' do
    it 'reads V2 files from the order location folder' do
      catalog = Davidsons::Catalog.new(fge)
      expect(catalog.send(:remote_path, 'V2_Qty.csv')).to eq('FGE/V2_Qty.csv')
    end

    it 'keeps legacy files at the root when there is no order location' do
      catalog = Davidsons::Catalog.new(credentials.except(:order_location))
      expect(catalog.send(:remote_path, 'davidsons_inventory.csv')).to eq('davidsons_inventory.csv')
    end

    it 'rejects an unknown order location' do
      expect { Davidsons::Catalog.all(credentials.merge(order_location: 'XYZ')) }.to raise_error(ArgumentError, /Unknown Davidsons order location/)
    end
  end

  describe 'Catalog.all' do
    let(:items) { by_id(Davidsons::Catalog.all(fge)) }

    it 'maps V2 columns to the legacy item keys' do
      rifle = items['00856']

      expect(rifle).to include(
        item_identifier: '00856',
        upc:             '847313008565',
        name:            'POF RENEGADE+ 5.56 16B 30RD',
        brand:           'POF USA',
        mfg_number:      '00856',
        model:           'Renegade+',
        msrp:            '2083.00',
        map_price:       '1898.00',
        category:        'Rifle: Semi-Automatic',
        subcategory:     nil,
        product_type:    'Firearm',
        action:          'Semi-Automatic',
        caliber:         '5.56 NATO',
        weight:          '14.300',
      )
      expect(rifle[:features]).to include(
        barrel_length: '16.500',
        capacity:      '30+1',
        image_name:    'https://res.cloudinary.com/davidsons-inc/image/upload/media/catalog/product/0/0/00856.jpg',
      )
    end

    it 'keeps leading zeros and has no # in UPCs' do
      expect(items['00004'][:upc]).to eq('021205000046')
      expect(items.values.map { |i| i[:upc] }).to all(match(/\A\d+\z/))
    end

    it 'joins ItemDesc1 and ItemDesc2 for the name' do
      expect(items['171102'][:name]).to eq('LEU RNGMNT BCTY 1IN MED 2P TIK TIKKA T3/T3X HUNT 1IN 2PC MED')
    end

    it 'falls back to Category/Subcategory when there is no GunType' do
      expect(items['04959']).to include(category: 'Ammo', subcategory: 'Centerfire', product_type: 'Ammo', caliber: '5.56 NATO')
    end

    it 'uses gQty for FGE' do
      expect(items.transform_values { |i| i[:quantity] }).to eq('00856' => 0, '00004' => 20, '171102' => 4, '04959' => 0)
    end

    it 'uses gQty for FPE too' do
      fpe_items = by_id(Davidsons::Catalog.all(fpe))
      expect(fpe_items.transform_values { |i| i[:quantity] }).to eq('00856' => 0, '00004' => 20, '171102' => 4, '04959' => 0)
    end

    context 'pricing' do
      it 'uses a running sale price when it is lower' do
        expect(items['00856'][:price]).to eq('1515.00')
      end

      it 'ignores an expired sale price' do
        expect(items['00004'][:price]).to eq('26.99')
      end

      it 'uses DealerPrice when there is no sale' do
        expect(items['171102'][:price]).to eq('67.69')
      end

      it 'ignores a sale that has not started yet' do
        allow(Date).to receive(:today).and_return(Date.new(2026, 7, 1))
        expect(by_id(Davidsons::Catalog.all(fge))['00856'][:price]).to eq('1736.00')
      end

      it 'uses MinPrice on the minimum tier' do
        minimum = by_id(Davidsons::Catalog.all(fge.merge(pricing_tier: :minimum)))
        expect(minimum['171102'][:price]).to eq('64.00')
      end

      it 'falls back to DealerPrice on the minimum tier when MinPrice is 0' do
        minimum = by_id(Davidsons::Catalog.all(fge.merge(pricing_tier: :minimum)))
        expect(minimum['00004'][:price]).to eq('26.99')
        expect(minimum['04959'][:price]).to eq('29.29')
      end
    end
  end

  describe 'Inventory.all' do
    it 'returns prices and quantities' do
      items = by_id(Davidsons::Inventory.all(fge))

      expect(items['00856']).to eq(item_identifier: '00856', upc: '847313008565', price: '1515.00', map_price: '1898.00', quantity: 0)
      expect(items['00004']).to eq(item_identifier: '00004', upc: '021205000046', price: '26.99', map_price: '39.99', quantity: 20)
    end
  end

  describe 'Inventory.quantity' do
    it 'reads V2_Qty with the location quantity' do
      items = by_id(Davidsons::Inventory.quantity(fpe))

      expect(items['171102']).to eq(
        item_identifier: '171102',
        upc:             '030317011468',
        quantity:        4,
        locations:       { g: '4', p: '5', g3: '0' },
      )
    end

    it 'only reads V2_Qty.csv' do
      inventory = Davidsons::Inventory.new(fge)
      expect(inventory).to receive(:get_file).once.with('V2_Qty.csv') { fixture_copy('V2_Qty.csv') }
      inventory.quantity
    end
  end

end
