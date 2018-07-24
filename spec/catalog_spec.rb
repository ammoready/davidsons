require 'spec_helper'

RSpec.describe Davidsons::Catalog do

  let(:credentials) {{ username: '', password: ''  }}

  before do
    tempfile = Tempfile.new('catalog_tempfile')
    FileUtils.copy_file(FixtureHelper.get_fixture('catalog.csv').path, tempfile.path)
    allow_any_instance_of(Davidsons::Catalog).to receive(:get_file) { tempfile }
  end

  describe '.all' do
    it 'yields items' do
      count = 0

      Davidsons::Catalog.all(credentials) do |item|
        count += 1

        case count
        when 1
          expect(item[:item_identifier]).to eq("1B222269")
          expect(item[:quantity]).to        eq(18)
          expect(item[:brand]).to           eq("Aguila")
        when 2
          expect(item[:item_identifier]).to eq("1B222328")
          expect(item[:caliber]).to         eq("22LR")
          expect(item[:price]).to           eq("2.39")
        end
      end

      expect(count).to eq(46)
    end
  end

end
