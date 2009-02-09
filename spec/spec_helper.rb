require 'rubygems'
require 'rubygems/server'
require 'sinatra/test'
require 'sinatra/test/unit'
require 'spec'
require 'spec/interop/test'
require 'stringio'
require 'webrick'
require 'rubygems/test_utilities'
require 'tmpdir'
require 'uri'

Sinatra::Default.set(
  :environment => :test,
  :run => false,
  :raise_errors => true,
  :logging => true
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
    @response.should be_ok

    #verify
    {
      :status =>          @response.status,
      :content_type =>    @response['Content-Type'],
      :body_length =>     ((method == :head) ? nil : @response.body.length )
    }.should == {
      :status =>          @webrick_response.status,
      :content_type =>    @webrick_response['Content-Type'],
      :body_length =>     ((method == :head) ? nil : @webrick_response.body.length )
    }
  end

  #stub gem
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

    tmpdir = nil
    Dir.chdir Dir.tmpdir do tmpdir = Dir.pwd end # HACK OSX /private/tmp
    @tempdir = File.join tmpdir, "test_rubygems_#{$$}"
    @tempdir.untaint
    @gemhome = File.join @tempdir, "gemhome"
    @gemcache = File.join(@gemhome, "source_cache")
    @usrcache = File.join(@gemhome, ".gem", "user_cache")
    @latest_usrcache = File.join(@gemhome, ".gem", "latest_user_cache")
    @userhome = File.join @tempdir, 'userhome'

    @orig_ENV_HOME = ENV['HOME']
    ENV['HOME'] = @userhome
    Gem.instance_variable_set :@user_home, nil

    FileUtils.mkdir_p @gemhome
    FileUtils.mkdir_p @userhome

    ENV['GEMCACHE'] = @usrcache
    Gem.use_paths(@gemhome)
    Gem.loaded_specs.clear

    Gem.configuration.verbose = true
    Gem.configuration.update_sources = true

    @gem_repo = "http://gems.example.com/"
    @uri = URI.parse @gem_repo
    Gem.sources.replace [@gem_repo]

    Gem::SpecFetcher.fetcher = nil

    @orig_BASERUBY = Gem::ConfigMap[:BASERUBY]
    Gem::ConfigMap[:BASERUBY] = Gem::ConfigMap[:RUBY_INSTALL_NAME]

    @orig_arch = Gem::ConfigMap[:arch]

    @marshal_version = "#{Marshal::MAJOR_VERSION}.#{Marshal::MINOR_VERSION}"

    @private_key = File.expand_path File.join(File.dirname(__FILE__), 'private_key.pem')
    @public_cert = File.expand_path File.join(File.dirname(__FILE__), 'public_cert.pem')

    @app = Rack::Builder.new {
      use GemsAndRdocs, :urls => ['/cache', '/doc'], :root => Gem.dir
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