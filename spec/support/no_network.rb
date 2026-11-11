# Specs must never reach a real Davidsons server; examples that need a
# connection stub Net::FTP.open / Net::SFTP.start themselves.
RSpec.configure do |config|
  config.before do
    allow(Net::FTP).to receive(:open).and_raise('Network access is disabled in specs (Net::FTP.open)')
    allow(Net::SFTP).to receive(:start).and_raise('Network access is disabled in specs (Net::SFTP.start)')
  end
end
