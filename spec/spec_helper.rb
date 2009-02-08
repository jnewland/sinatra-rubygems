require 'rubygems'
require 'rubygems/server'
require 'sinatra/test'
require 'sinatra/test/unit'
require 'spec'
require 'spec/interop/test'
require 'stringio'
require 'webrick'
 
Sinatra::Default.set(
  :environment => :test,
  :run => false,
  :raise_errors => true,
  :logging => false
)

require File.expand_path(File.dirname(__FILE__) + "/../lib/rack_rubygems.rb")

module RackRubygemsTestHelpers

  def should_match_webrick_behavior(url, server_method, method = :get)
    #webrick
    data = StringIO.new "#{method.to_s.capitalize} #{url} HTTP/1.0\r\n\r\n"
    @webrick_request.parse data

    @webrick.send(server_method, @webrick_request, @webrick_response)
    #sinatra
    send(method, url)

    #verify
    @response['Content-Type'].should == @webrick_response['Content-Type']
    @response.status.should == @webrick_response.status

    if method == :head
      #the default gem server misbehaves and never sends a Content-Length
      #header, so we only check on HEAD requests, which are only implemented
      #in the gem server for providing gem counts via Content-Length
      @response.headers['Content-Length'].to_i.should > 0
    else
      #the default gem server misbehaves and returns a body when retrieving a
      #HEAD request, so we don't verify
      @response.body.length.should == @webrick_response.body.length
    end
  end

  def quick_gem(gemname, version='2')
    require 'rubygems/specification'

    spec = Gem::Specification.new do |s|
      s.platform = Gem::Platform::RUBY
      s.name = gemname
      s.version = version
      s.author = 'A User'
      s.email = 'example@example.com'
      s.homepage = 'http://example.com'
      s.has_rdoc = true
      s.summary = "this is a summary"
      s.description = "This is a test description"

      yield(s) if block_given?
    end

    path = File.join "specifications", "#{spec.full_name}.gemspec"
    written_path = write_file path do |io|
      io.write(spec.to_ruby)
    end

    spec.loaded_from = written_path

    Gem.source_index.add_spec spec

    return spec
  end

  def write_file(path)
    tmpdir = nil
    Dir.chdir Dir.tmpdir do tmpdir = Dir.pwd end # HACK OSX /private/tmp
    @tempdir = File.join tmpdir, "test_rubygems_#{$$}"
    @tempdir.untaint
    @gemhome = File.join @tempdir, "gemhome"
    path = File.join(@gemhome, path)
    dir = File.dirname path
    FileUtils.mkdir_p dir

    open path, 'wb' do |io|
      yield io
    end

    path
  end

  def process_based_port
    @@process_based_port ||= 8000 + $$ % 1000
  end

end

Spec::Runner.configure do |config|
  config.before(:each) {
    @app = Rack::Builder.new {
      use GemsAndRdocs, :urls => ['/cache', '/doc'], :root => Gem.dir
      use Rack::Compress
      run RackRubygems.new
    }
    @a1 = quick_gem 'a', '1'
    @a2 = quick_gem 'a', '2'

    @webrick = Gem::Server.new Gem.dir, process_based_port, false
    @webrick_request = WEBrick::HTTPRequest.new :Logger => nil
    @webrick_response = WEBrick::HTTPResponse.new :HTTPVersion => '1.0'
  }
  config.include Sinatra::Test
  config.include RackRubygemsTestHelpers
end