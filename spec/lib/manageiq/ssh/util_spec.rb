require 'manageiq/ssh/util'

RSpec.describe ManageIQ::SSH::Util do
  context "#get_file" do
    let(:ssh_util) { described_class.new('localhost', 'temp', 'something') }
    let(:ssh_session) { double(Net::SSH::Connection::Session) }
    let(:sftp_session) { double(Net::SFTP::Session) }
    let(:sftp_download) { double(Net::SFTP::Operations::Download) }

    before do
      allow(ssh_util).to receive(:run_session).and_return(ssh_session)
      allow(ssh_session).to receive(:sftp).and_return(sftp_session)
      allow(sftp_session).to receive(:dowload!).and_return(sftp_download)
    end

    it "retrieves a remote file" do
      pending "This is returning the ssh connection for some reason"
      allow(sftp_session).to receive(:download!).and_return(sftp_download)
      expect(ssh_util.get_file('remote_file', 'local_file')).to eql(sftp_download)
    end
  end

  context "#temp_cmd_file" do
    let(:ssh) { ManageIQ::SSH::Util.new("localhost", "temp", "something") }

    it "creates a file" do
      count = Dir.glob("/var/tmp/miq-*").size

      ssh.temp_cmd_file("pwd") do |_cmd|
        expect(Dir.glob("/var/tmp/miq-*").size).to eq(count + 1)
      end
    end

    it "writes to file" do
      ssh.temp_cmd_file("pwd") do |cmd|
        expect(File.read(cmd.split(";")[1].strip)).to eq("pwd")
      end
    end

    it "deletes the file" do
      count = Dir.glob("/var/tmp/miq-*").size
      ssh.temp_cmd_file("pwd") {}

      expect(Dir.glob("/var/tmp/miq-*").size).to eq(count)
    end
  end
end
