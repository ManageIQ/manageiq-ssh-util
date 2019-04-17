require 'manageiq/ssh/util'

RSpec.describe ManageIQ::SSH::Util do
  let(:host) { 'localhost' }
  let(:ssh_session) { double(Net::SSH::Connection::Session) }
  let(:sftp_session) { double(Net::SFTP::Session) }
  let(:sftp_download) { double(Net::SFTP::Operations::Download) }
  let(:ssh_util) { described_class.new(host, 'temp', 'something') }
  let(:logger_file) { StringIO.new }

  before do
    $log = Logger.new(logger_file)
    allow(ssh_util).to receive(:run_session).and_yield(ssh_session)
    allow(ssh_session).to receive(:sftp).and_return(sftp_session)
    allow(sftp_session).to receive(:download!).and_return(sftp_download)
  end

  context "#get_file" do
    let(:from) { 'remote_file' }
    let(:to) { 'local_file' }

    it "retrieves a remote file" do
      allow(sftp_session).to receive(:download!).and_return(sftp_download)
      expect(ssh_util.get_file(from, to)).to eql(sftp_download)
    end

    it "writes the expected message to the log file" do
      ssh_util.get_file(from, to)
      logger_file.rewind
      logger_contents = logger_file.read
      expect(logger_contents).to include("MiqSshUtil::get_file - Copying file #{host}:#{from} to #{to}.")
      expect(logger_contents).to include("MiqSshUtil::get_file - Copying of #{host}:#{from} to #{to}, complete.")
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
