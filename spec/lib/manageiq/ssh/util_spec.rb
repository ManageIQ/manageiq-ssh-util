RSpec.describe ManageIQ::SSH::Util do
  let(:host) { 'localhost' }
  let(:ssh_session) { instance_double(Net::SSH::Connection::Session) }
  let(:ssh_channel) { instance_double(Net::SSH::Connection::Channel) }
  let(:sftp_session) { instance_double(Net::SFTP::Session) }
  let(:sftp_download) { instance_double(Net::SFTP::Operations::Download) }
  let(:ssh_util) { described_class.new(host, 'temp', 'something') }
  let(:logger_file) { StringIO.new }
  let(:data) { Net::SSH::Buffer.new([0].pack('N')) }

  before do
    $log = Logger.new(logger_file)
    allow(ssh_util).to receive(:run_session).and_yield(ssh_session)
    allow(ssh_session).to receive(:sftp).and_return(sftp_session)
    allow(sftp_session).to receive(:download!).and_return(sftp_download)
  end

  def stub_channels
    allow(ssh_channel).to receive(:on_data).and_yield(ssh_channel, 'some_data')
    allow(ssh_channel).to receive(:on_request).with('exit-status').and_yield(ssh_channel, data)
    allow(ssh_channel).to receive(:on_request).with('exit-signal').and_yield(ssh_channel, data)
    allow(ssh_channel).to receive(:on_eof).and_yield(ssh_channel)
    allow(ssh_channel).to receive(:on_close).and_yield(ssh_channel)
    allow(ssh_channel).to receive(:on_extended_data).and_yield(ssh_channel, 1, '')
  end

  def lastlog
    logger_file.rewind
    logger_file.read
  end

  context "#options" do
    it "returns the expected default values for options" do
      expect(ssh_util.options[:verbose]).to eql(:warn)
      expect(ssh_util.options[:non_interactive]).to eql(true)
      expect(ssh_util.options[:use_agent]).to eql(false)
    end
  end

  context "#remember_host?" do
    it "returns a boolean value indicating whether or not the remember host option is set" do
      expect(ssh_util.remember_host?).to eql(false)
    end
  end

  context "#host" do
    it "returns the value of the host passed to the constructor" do
      expect(ssh_util.host).to eql(host)
    end
  end

  context "#user" do
    it "returns the value of the user passed to the constructor" do
      expect(ssh_util.user).to eql('temp')
    end
  end

  context "#shell_with_su" do
    before do
      @remote_user = 'some_remote_user'
      @remote_pass = 'some_remote_password'
      @sudo_user   = 'some_sudo_user'
      @sudo_pass   = 'some_sudo_password'
    end

    it "requires remote user and password, as well as sudo user and password" do
      expect { described_class.shell_with_su(host) }.to raise_error(ArgumentError)
      expect { described_class.shell_with_su(host, @remote_user, @remote_password) }.to raise_error(ArgumentError)
    end

    it "requires a block and yields arguments" do
      expect { |b| described_class.shell_with_su(host, @remote_user, @remote_pass, @sudo_user, @sudo_pass, &b) }.to yield_with_args
    end

    it "creates a manageiq-ssh-util object with the expected attributes" do
      described_class.shell_with_su(host, @remote_user, @remote_pass, @sudo_user, @sudo_pass) do |ssh_util|
        expect(ssh_util.options).to include(:verbose => :warn, :use_agent => false, :non_interactive => true, :password => @remote_pass)
        expect(ssh_util.options).not_to include(:remember_host, :su_user, :su_password, :passwordless_sudo)
        expect(ssh_util.host).to eql(host)
        expect(ssh_util.user).to eql(@remote_user)
      end
    end
  end

  context "#exec", :exec do
    before do
      stub_channels
      allow(ssh_session).to receive(:open_channel).and_yield(ssh_channel)
      allow(ssh_session).to receive(:loop)
    end

    it "raises an error if the command is unsuccessful" do
      allow(ssh_channel).to receive(:exec).and_yield(ssh_channel, false)
      expect { ssh_util.exec('bogus') }.to raise_error(RuntimeError)
    end

    it "returns the expected result if the command is successful" do
      allow(ssh_channel).to receive(:exec).and_yield(ssh_channel, true)
      expect(ssh_util.exec('whatever')).to eql('some_data')
    end

    it "returns the expected result if the command is successful, but returns an error message" do
      allow(ssh_channel).to receive(:exec).and_yield(ssh_channel, true)
      allow(ssh_channel).to receive(:on_extended_data).and_yield(ssh_channel, 1, 'some_extended_data')
      expect { ssh_util.exec('whatever') }.to raise_error(RuntimeError, /some_extended_data/)
    end

    it "logs the expected message if the command is successful" do
      command = 'uname -a'

      allow(ssh_channel).to receive(:exec).and_yield(ssh_channel, true)
      allow(ssh_util.exec(command))

      expect(lastlog).to include("Command: #{command}, exit status: 0")
    end

    it "logs the expected channel messages" do
      command = 'uname -a'

      allow(ssh_channel).to receive(:exec).and_yield(ssh_channel, true)
      allow(ssh_util.exec(command))

      expect(lastlog).to include("STDOUT")
      expect(lastlog).to include("STDERR")
      expect(lastlog).to include("STATUS")
      expect(lastlog).to include("SIGNAL")
      expect(lastlog).to include("EOF RECEIVED")
    end
  end

  context "#put_file" do
    let(:target) { Tempfile.new }
    let(:source) { Tempfile.new }

    before do
      allow(sftp_session).to receive(:file).and_return(File)
    end

    it "raises an error if no target is provided" do
      expect { ssh_util.put_file }.to raise_error(ArgumentError)
    end

    it "raises an error if both the content and path are nil" do
      error_msg = "Need to provide either content or path"
      expect { ssh_util.put_file('stuff') }.to raise_error(ArgumentError, error_msg)
    end

    it "puts file content as expected if content is provided" do
      expect(ssh_util.put_file(target.path, 'hello')).to be_truthy
      expect(target.read).to eql('hello')
    end

    it "puts file content as expected if a path is provided" do
      source.write('world') and source.rewind

      expect(ssh_util.put_file(target.path, nil, source.path)).to be_truthy
      expect(target.read).to eql('world')
    end

    it "writes the expected message to the log file" do
      ssh_util.put_file(target.path, 'stuff')
      expect(lastlog).to include("ManageIQ::SSH::Util#put_file - Copying file to #{host}:#{target.path}.")
      expect(lastlog).to include("ManageIQ::SSH::Util#put_file - Copying of file to #{host}:#{target.path}, complete.")
    end
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
      expect(lastlog).to include("ManageIQ::SSH::Util#get_file - Copying file #{host}:#{from} to #{to}.")
      expect(lastlog).to include("ManageIQ::SSH::Util#get_file - Copying of #{host}:#{from} to #{to}, complete.")
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
