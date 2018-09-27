require 'spec_helper'

RSpec.describe Davidsons::Inventory do

  let(:credentials) {{ username: 'usr', password: 'psw'  }}

  describe '.all' do
    before do
      tempfile = Tempfile.new(['davidsons_inventory', '.csv'])
      FileUtils.copy_file(FixtureHelper.get_fixture('davidsons_inventory.csv').path, tempfile.path)
      allow_any_instance_of(Davidsons::Inventory).to receive(:get_file) { tempfile }
    end

    context 'regular pricing' do
      it 'yields items (including pricing)' do
        count = 0
        Davidsons::Inventory.all(credentials) do |item|
          count += 1
          case count
          when 1
            expect(item[:item_identifier]).to eq('A00001')
            expect(item[:quantity]).to eq(20)
            expect(item[:price]).to eq('3.49')
          when 22
            expect(item[:item_identifier]).to eq('A00022')
            expect(item[:quantity]).to eq(25)
            expect(item[:price]).to eq('351.99')
          when 46
            expect(item[:item_identifier]).to eq('C00046')
            expect(item[:quantity]).to eq(25)
            expect(item[:price]).to eq('339.99')
          end
        end
      end
    end

    context 'minimum pricing' do
      it 'yields items (including pricing)' do
        count = 0
        Davidsons::Inventory.all(credentials.merge(pricing_tier: :minimum)) do |item|
          count += 1
          case count
          when 1
            expect(item[:item_identifier]).to eq('A00001')
            expect(item[:quantity]).to eq(20)
            expect(item[:price]).to eq('3.49')
          when 22
            expect(item[:item_identifier]).to eq('A00022')
            expect(item[:quantity]).to eq(25)
            expect(item[:price]).to eq('300.99')
          when 46
            expect(item[:item_identifier]).to eq('C00046')
            expect(item[:quantity]).to eq(25)
            expect(item[:price]).to eq('290.99')
          end
        end
      end
    end
  end

  describe '.quantity' do
    before do
      tempfile = Tempfile.new(['davidsons_quantity', '.csv'])
      FileUtils.copy_file(FixtureHelper.get_fixture('davidsons_quantity.csv').path, tempfile.path)
      allow_any_instance_of(Davidsons::Inventory).to receive(:get_file) { tempfile }
    end

    it 'yields items (only quantity)' do
      count = 0
      Davidsons::Inventory.quantity(credentials) do |item|
        count += 1
        case count
        when 22
          expect(item[:item_identifier]).to eq('A00022')
          expect(item[:quantity]).to eq(50)
          expect(item[:price]).to eq(nil)
        end
      end
    end
  end

end
