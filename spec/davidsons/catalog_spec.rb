require 'spec_helper'

RSpec.describe Davidsons::Catalog do

  let(:credentials) {{ username: 'usr', password: 'psw'  }}

  before do
    tempfile = Tempfile.new('catalog_tempfile')
    FileUtils.copy_file(FixtureHelper.get_fixture('catalog.csv').path, tempfile.path)
    allow_any_instance_of(Davidsons::Catalog).to receive(:get_file) { tempfile }
  end

  describe '.all' do
    context 'regular pricing tier' do
      it 'yields items' do
        count = 0

        Davidsons::Catalog.all(credentials) do |item|
          count += 1

          case count
          when 1
            expect(item[:item_identifier]).to eq('A00001')
            expect(item[:quantity]).to        eq(20)
            expect(item[:brand]).to           eq('Smuger')
          when 2
            expect(item[:item_identifier]).to eq('A00002')
            expect(item[:caliber]).to         eq('22LR')
            expect(item[:price]).to           eq('2.39')
          end
        end

        expect(count).to eq(46)
      end
    end

    context 'item has sale price' do
      it 'yields items' do
        count = 0

        Davidsons::Catalog.all(credentials) do |item|
          count += 1

          case count
          when 22
            expect(item[:item_identifier]).to eq('A00022')
            expect(item[:price]).to           eq('351.99')
          when 23
            expect(item[:item_identifier]).to eq('A00023')
            expect(item[:price]).to           eq('352.99')
          when 24
            expect(item[:item_identifier]).to eq('A00024')
            expect(item[:price]).to           eq('353.99')
          end
        end
      end
    end

    context 'minimum pricing tier' do
      it 'yields items' do
        count = 0

        Davidsons::Catalog.all(credentials.merge(pricing_tier: :minimum)) do |item|
          count += 1

          case count
          when 22
            expect(item[:item_identifier]).to eq('A00022')
            expect(item[:price]).to           eq('300.99')
          when 23
            expect(item[:item_identifier]).to eq('A00023')
            expect(item[:price]).to           eq('352.99')
          when 45
            expect(item[:item_identifier]).to eq('C00045')
            expect(item[:price]).to           eq('590.99')
          when 46
            expect(item[:item_identifier]).to eq('C00046')
            expect(item[:price]).to           eq('290.99')
          end
        end

        expect(count).to eq(46)
      end
    end
  end

end
