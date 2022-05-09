# -*- coding:binary -*-

require 'rex/mime'

# Note: Some of these tests require a failed
# connection to 127.0.0.1:1. If you have some crazy local
# firewall that is dropping packets to this, your tests
# might be slow.
RSpec.describe Rex::Proto::Http::Client do

  class << self

    # Set a standard excuse that indicates that the method
    # under test needs to be first examined to figure out
    # what's sane and what's not.
    def excuse_lazy(test_method=nil)
      ret = "need to determine pass/fail criteria"
      test_method ? ret << " for #{test_method.inspect}" : ret
    end

    # Complain about not having a "real" connection (can be mocked)
    def excuse_needs_connection
      "need to actually set up an HTTP server to test"
    end

    # Complain about not having a real auth server (can be mocked)
    def excuse_needs_auth
      "need to set up an HTTP authentication challenger"
    end

  end

  let(:ip) { "1.2.3.4" }

  subject(:cli) do
    Rex::Proto::Http::Client.new(ip)
  end

  describe "#set_config" do

    it "should respond to #set_config" do
      expect(cli.set_config).to eq({})
    end

  end

  it "should respond to initialize" do
    expect(cli).to be
  end

  it "should have a set of default instance variables" do
    expect(cli.instance_variable_get(:@hostname)).to eq ip
    expect(cli.instance_variable_get(:@port)).to eq 80
    expect(cli.instance_variable_get(:@context)).to eq({})
    expect(cli.instance_variable_get(:@ssl)).to be_falsey
    expect(cli.instance_variable_get(:@proxies)).to be_nil
    expect(cli.instance_variable_get(:@username)).to be_empty
    expect(cli.instance_variable_get(:@password)).to be_empty
    expect(cli.config).to be_a_kind_of Hash
  end

  it "should produce a raw HTTP request" do
    expect(cli.request_raw).to be_a_kind_of Rex::Proto::Http::ClientRequest
  end

  it "should produce a CGI HTTP request" do
    req = cli.request_cgi
    expect(req).to be_a_kind_of Rex::Proto::Http::ClientRequest
  end

  context "with authorization" do
    subject(:cli) do
      cli = Rex::Proto::Http::Client.new(ip)
      cli.set_config({"authorization" => "Basic base64dstuffhere"})
      cli
    end
    let(:user)   { "user" }
    let(:pass)   { "pass" }
    let(:base64) { ["user:pass"].pack('m').chomp }

    context "and an Authorization header" do
      before do
        cli.set_config({"headers" => { "Authorization" => "Basic #{base64}" } })
      end
      it "should have one Authorization header" do
        req = cli.request_cgi
        match = req.to_s.match("Authorization: Basic")
        expect(match).to be
        expect(match.length).to eq 1
      end
      it "should prefer the value in the header" do
        req = cli.request_cgi
        match = req.to_s.match(/Authorization: Basic (.*)$/)
        expect(match).to be
        expect(match.captures.length).to eq 1
        expect(match.captures[0].chomp).to eq base64
      end
    end
  end

  context "with credentials" do
    subject(:cli) do
      cli = Rex::Proto::Http::Client.new(ip)
      cli
    end
    let(:first_response) {
      "HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\nWWW-Authenticate: Basic realm=\"foo\"\r\n\r\n"
    }
    let(:authed_response) {
      "HTTP/1.1 200 Ok\r\nContent-Length: 0\r\n\r\n"
    }
    let(:user) { "user" }
    let(:pass) { "pass" }

    it "should not send creds on the first request in order to induce a 401" do
      req = subject.request_cgi
      expect(req.to_s).not_to match("Authorization:")
    end

    it "should send creds after receiving a 401" do
      conn = double
      allow(conn).to receive(:put)
      allow(conn).to receive(:peerinfo)
      allow(conn).to receive(:shutdown)
      allow(conn).to receive(:close)
      allow(conn).to receive(:closed?).and_return(false)

      expect(conn).to receive(:get_once).and_return(first_response, authed_response)
      expect(conn).to receive(:put) do |str_request|
        expect(str_request).not_to include("Authorization")
        nil
      end
      expect(conn).to receive(:put) do |str_request|
        expect(str_request).to include("Authorization")
        nil
      end

      expect(cli).to receive(:_send_recv).twice.and_call_original

      allow(Rex::Socket::Tcp).to receive(:create).and_return(conn)

      opts = { "username" => user, "password" => pass}
      req = cli.request_cgi(opts)
      cli.send_recv(req)

      # Make sure it didn't modify the argument
      expect(opts).to eq({ "username" => user, "password" => pass})
    end

  end

  it "should attempt to connect to a server" do
    this_cli = Rex::Proto::Http::Client.new("127.0.0.1", 1)
    expect { this_cli.connect(1) }.to raise_error ::Rex::ConnectionRefused
  end

  it "should be able to close a connection" do
    expect(cli.close).to be_nil
  end

  it "should send a request and receive a response", :skip => excuse_needs_connection do

  end

  it "should send a request and receive a response without auth handling", :skip => excuse_needs_connection do

  end

  it "should send a request", :skip => excuse_needs_connection do

  end

  it "should test for credentials" do
    skip "Should actually respond to :has_creds" do
      expect(cli).not_to have_creds
      this_cli = described_class.new("127.0.0.1", 1, {}, false, nil, nil, "user1", "pass1" )
      expect(this_cli).to have_creds
    end
  end

  it "should send authentication", :skip => excuse_needs_connection

  it "should produce a basic authentication header" do
    u = "user1"
    p = "pass1"
    b64 = ["#{u}:#{p}"].pack("m*").strip
    expect(cli.basic_auth_header("user1","pass1")).to eq "Basic #{b64}"
  end

  it "should perform digest authentication", :skip => excuse_needs_auth do

  end

  it "should perform negotiate authentication", :skip => excuse_needs_auth do

  end

  it "should get a response", :skip => excuse_needs_connection do

  end

  it "should end a connection with a stop" do
    expect(cli.stop).to be_nil
  end

  it "should test if a connection is valid" do
    expect(cli.conn?).to be_falsey
  end

  it "should tell if pipelining is enabled" do
    expect(cli).not_to be_pipelining
    this_cli = Rex::Proto::Http::Client.new("127.0.0.1", 1)
    this_cli.pipeline = true
    expect(this_cli).to be_pipelining
  end

  it "should respond to its various accessors" do
    expect(cli).to respond_to :config
    expect(cli).to respond_to :config_types
    expect(cli).to respond_to :pipeline
    expect(cli).to respond_to :local_host
    expect(cli).to respond_to :local_port
    expect(cli).to respond_to :conn
    expect(cli).to respond_to :context
    expect(cli).to respond_to :proxies
    expect(cli).to respond_to :username
    expect(cli).to respond_to :password
    expect(cli).to respond_to :junk_pipeline
  end

  # Not super sure why these are protected...
  # Me either...
  # Same here...
  it "should refuse access to its protected accessors" do
    expect {cli.ssl}.to raise_error NoMethodError
    expect {cli.ssl_version}.to raise_error NoMethodError
    expect {cli.hostname}.to raise_error NoMethodError
    expect {cli.port}.to raise_error NoMethodError
  end

  context 'with form_data' do
    subject(:cli) do
      cli = Rex::Proto::Http::Client.new(ip)
      cli.config['data'] = ''
      cli.config['method'] = 'POST'
      cli
    end

    let(:file_path) do
      ::File.join(::Msf::Config.install_root, 'spec', 'file_fixtures', 'string_list.txt')
    end
    let(:file) do
      ::File.open(file_path, 'rb')
    end
    let(:mock_boundary_suffix) do
      'MockBoundary1234'
    end

    before(:each) do
      file.rewind
      allow(Rex::Text).to receive(:rand_text_numeric).with(30).and_return(mock_boundary_suffix)
    end

    it 'should parse field name and file object as data' do
      form_data = [
        { 'name' => 'field1', 'data' => file }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      # We are gsub'ing here as HttpClient does this gsub to non-binary file data
      file_contents = file.read.gsub("\r", '').gsub("\n", "\r\n")

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 247\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="field1"; filename="string_list.txt"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
#{file_contents}\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should parse field name and binary file object as data' do
      form_data = [
        { 'name' => 'field1', 'data' => file, 'encoding' => 'binary' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 247\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="field1"; filename="string_list.txt"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: binary\r
\r
#{file.read}\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should parse field name and binary file object as data with filename override' do
      form_data = [
        { 'name' => 'field1', 'data' => file, 'encoding' => 'binary', 'filename' => 'my_file.txt' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 243\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="field1"; filename="my_file.txt"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: binary\r
\r
#{file.read}\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should parse data correctly when provided with a string' do
      data = 'hello world'
      form_data = [
        { 'name' => 'file1', 'data' => data }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expect(request.to_s).to include('Content-Disposition: form-data; name="file1"')
      expect(request.to_s).to include(data)

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 234\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file1"; filename="file1"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
#{data}\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should parse data correctly when provided with a string and mime type' do
      data = 'hello world'
      form_data = [
        { 'name' => 'file1', 'data' => data, 'mime_type' => 'text/plain' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 234\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file1"; filename="file1"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
#{data}\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should parse data correctly when provided with a string, mime type and filename' do
      data = 'hello world'
      form_data = [
        { 'name' => 'file1', 'data' => data, 'mime_type' => 'text/plain', 'filename' => 'my_file.txt' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 240\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file1"; filename="my_file.txt"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
#{data}\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should parse data correctly when provided with a number' do
      data = 123
      form_data = [
        { 'name' => 'file1', 'data' => data, 'mime_type' => 'text/plain' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 226\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file1"; filename="file1"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
#{data}\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should parse dat correctly when provided with an IO object' do
      require 'stringio'

      str = 'Hello World!'
      form_data = [
        { 'name' => 'file1', 'data' => ::StringIO.new(str), 'mime_type' => 'text/plain', 'filename' => 'my_file.txt' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 241\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file1"; filename="my_file.txt"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
#{str}\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should handle nil data values correctly' do
      form_data = [
        { 'name' => 'nil_value', 'data' => nil }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      # This could potentially return one less '\r'.
      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 231\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="nil_value"; filename="nil_value"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should handle nil field values correctly' do
      form_data = [
        { 'name' => nil, 'data' => '123' },
        { 'data' => '456' },
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 339\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
123\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
456\r
-----------------------------MockBoundary1234--\r
      EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should handle nil field values and data correctly' do
      form_data = [
        { 'name' => nil, 'data' => nil }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 191\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should handle non-string field name values correctly' do
      form_data = [
        { 'name' => false, 'data' => '123' },
        { 'name' => true, 'data' => '456' },
        { 'name' => ['hello'], 'data' => '789' },
        { 'name' => { k: 'val' }, 'data' => '101112' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 632\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
123\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
456\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
789\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
101112\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should handle binary correctly' do
      form_data = [
        { 'name' => 'field1', 'data' => "\x05\x00\x68\x65\x6c\x6c\x6f".unpack('Sa*'), 'encoding' => 'binary' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 239\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="field1"; filename="field1"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: binary\r
\r
[5, "hello"]\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should handle duplicate file and field names correctly' do
      form_data = [
        { 'name' => 'file', 'data' => 'file1_content', 'filename' => 'duplicate.txt' },
        { 'name' => 'file', 'data' => 'file2_content', 'filename' => 'duplicate.txt' },
        { 'name' => 'file', 'data' => 'file2_content', 'filename' => 'duplicate.txt' },
        # Note, this won't actually attempt to read a file - the content will be set to 'file.txt'
        { 'name' => 'file', 'data' => 'file.txt', 'filename' => 'duplicate.txt' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 820\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file"; filename="duplicate.txt"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
file1_content\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file"; filename="duplicate.txt"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
file2_content\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file"; filename="duplicate.txt"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
file2_content\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file"; filename="duplicate.txt"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
file.txt\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should escape special characters in file names correctly without encoding' do
      form_data = [
        { 'name' => 'file', 'data' => 'abc', 'filename' => "'t \"e 'st.txt'" }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 242\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file"; filename="#{::CGI.escape(form_data[0]['filename'])}"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
abc\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should escape special characters in file names correctly with encoding' do
      form_data = [
        { 'name' => 'file', 'data' => 'abc', 'filename' => "'t \"e 'st.txt'", 'encoding' => 'base64' }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 244\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="file"; filename="#{::CGI.escape(form_data[0]['filename'])}"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: base64\r
\r
abc\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should handle nil filename values correctly' do
      form_data = [
        { 'name' => 'example_name', 'data' => 'example_data', 'filename' => nil }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 224\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="example_name"\r
Content-Type: text/plain\r
Content-Transfer-Encoding: 8bit\r
\r
example_data\r
-----------------------------MockBoundary1234--\r
EOF
      expect(request.to_s).to eq(expected)
    end

    it 'should handle nil encoding values correctly' do
      form_data = [
        { 'name' => 'example_name', 'data' => 'example_data', 'encoding' => nil }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 216\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="example_name"; filename="example_name"\r
Content-Type: text/plain\r
\r
example_data\r
-----------------------------MockBoundary1234--\r
EOF

      expect(request.to_s).to eq(expected)
    end

    it 'should handle nil mime type values correctly' do
      form_data = [
        { 'name' => 'example_name', 'data' => 'example_data', 'mime_type' => nil }
      ]

      request = cli.request_cgi({ 'form_data' => form_data })

      expected = <<~EOF
POST / HTTP/1.1\r
Host: #{ip}\r
User-Agent: #{request.opts['agent']}\r
Content-Type: multipart/form-data; boundary=---------------------------MockBoundary1234\r
Content-Length: 223\r
\r
-----------------------------MockBoundary1234\r
Content-Disposition: form-data; name="example_name"; filename="example_name"\r
Content-Transfer-Encoding: 8bit\r
\r
example_data\r
-----------------------------MockBoundary1234--\r
      EOF

      expect(request.to_s).to eq(expected)
    end
  end
end
