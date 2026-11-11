require 'spec_helper'

RSpec.describe Davidsons::Base do

  let(:credentials) {{ username: 'usr', password: 'psw' }}
  let(:ftp)         { instance_double(Net::FTP, :passive= => true, :debug_mode= => true, pwd: '/') }

  describe '.connect' do
    it 'uses the global ftp_host by default' do
      expect(Net::FTP).to receive(:open).with(Davidsons.config.ftp_host, 'usr', 'psw').and_yield(ftp)

      Davidsons::Base.connect(credentials) { |f| f.pwd }
    end

    it 'uses the :ftp_host option when given' do
      expect(Net::FTP).to receive(:open).with('ftp.davidsons.com', 'usr', 'psw').and_yield(ftp)

      Davidsons::Base.connect(credentials.merge(ftp_host: 'ftp.davidsons.com')) { |f| f.pwd }
    end

    it 'falls back to the global ftp_host when :ftp_host is blank' do
      expect(Net::FTP).to receive(:open).with(Davidsons.config.ftp_host, 'usr', 'psw').and_yield(ftp)

      Davidsons::Base.connect(credentials.merge(ftp_host: ' ')) { |f| f.pwd }
    end
  end

  describe 'SFTP' do
    let(:options) { credentials.merge(ftp_host: 'ftp.davidsons.com', protocol: 'sftp', port: 22) }
    let(:sftp)    { double('Net::SFTP::Session') }

    it 'connects with Net::SFTP when protocol is sftp' do
      expect(Net::FTP).not_to receive(:open)
      expect(Net::SFTP).to receive(:start).
        with('ftp.davidsons.com', 'usr', password: 'psw', port: 22, non_interactive: true).
        and_yield(sftp)

      Davidsons::Base.connect(options) { |conn| expect(conn).to be(sftp) }
    end

    it 'defaults the port to 22' do
      expect(Net::SFTP).to receive(:start).with('ftp.davidsons.com', 'usr', hash_including(port: 22)).and_yield(sftp)

      Davidsons::Base.connect(options.except(:port)) { |_| }
    end

    it 'raises NotAuthenticated on a bad login' do
      allow(Net::SFTP).to receive(:start).and_raise(Net::SSH::AuthenticationFailed, 'usr')

      expect { Davidsons::Base.connect(options) { |_| } }.to raise_error(Davidsons::NotAuthenticated)
      expect(Davidsons::User.new(options).authenticated?).to be(false)
    end

    it 'authenticates by listing the root folder' do
      expect(sftp).to receive(:dir).and_return(double(entries: []))
      allow(Net::SFTP).to receive(:start).and_yield(sftp)

      expect(Davidsons::User.new(options).authenticated?).to be(true)
    end

    it "returns the block's result even though Net::SFTP.start returns nil" do
      # The real Net::SFTP.start runs the block, closes the session and returns nil
      allow(Net::SFTP).to receive(:start) { |*_, &block| block.call(sftp); nil }

      expect(Davidsons::Base.connect(options) { |_| :downloaded }).to eq(:downloaded)
    end

    it 'returns the downloaded file from get_file' do
      allow(Net::SFTP).to receive(:start) { |*_, &block| block.call(sftp); nil }
      allow(sftp).to receive(:download!) { |_, local| File.write(local, "UPC,SKU,gQty,pQty,g3Qty\n1,00001,5,0,0\n") }

      items = Davidsons::Inventory.quantity(options.merge(order_location: 'FGE'))

      expect(items).to eq([{ item_identifier: '00001', upc: '1', quantity: 5, locations: { g: '5', p: '0', g3: '0' } }])
    end

    it "downloads from the order location's folder" do
      allow(Net::SFTP).to receive(:start).and_yield(sftp)
      expect(sftp).to receive(:download!).with('FGE/V2_Qty.csv', kind_of(String))
      allow(SmarterCSV).to receive(:process)
      allow(CSV).to receive(:foreach).and_return([])

      Davidsons::Inventory.quantity(options.merge(order_location: 'FGE'))
    end
  end

  describe ':ftp_host is used by every FTP call' do
    let(:options) { credentials.merge(ftp_host: 'ftp.davidsons.com') }

    before do
      allow(ftp).to receive(:getbinaryfile)
      expect(Net::FTP).to receive(:open).with('ftp.davidsons.com', 'usr', 'psw').and_yield(ftp)
    end

    it 'Davidsons::User#authenticated?' do
      expect(Davidsons::User.new(options).authenticated?).to be(true)
    end

    it 'Davidsons::Catalog.all' do
      allow(SmarterCSV).to receive(:process)
      Davidsons::Catalog.all(options)
    end

    it 'Davidsons::Inventory.all' do
      allow(SmarterCSV).to receive(:process)
      Davidsons::Inventory.all(options)
    end

    it 'Davidsons::Inventory.quantity' do
      allow(SmarterCSV).to receive(:process)
      Davidsons::Inventory.quantity(options)
    end
  end

end
