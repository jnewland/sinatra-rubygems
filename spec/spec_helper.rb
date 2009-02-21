require 'rubygems'
require 'rubygems/server'
require 'sinatra/test'
require 'sinatra/test/unit'
require 'spec'
require 'spec/interop/test'
require 'stringio'
require 'webrick'
require File.expand_path(File.dirname(__FILE__) + "/../lib/rack_rubygems.rb")

Sinatra::Default.set(
  :environment => :test,
  :run => false,
  :raise_errors => true,
  :logging => true
)

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

end

Spec::Runner.configure do |config|
  config.before(:each) {
    #mock the gem index
    @source_index = Gem::SourceIndex.from_gems_in File.expand_path(File.dirname(__FILE__) + "/gems")
    Gem::SourceIndex.should_receive(:from_gems_in).any_number_of_times.and_return(@source_index.refresh!)

    #sinatra
    @app = Rack::Builder.new {
      use GemsAndRdocs, :urls => ['/cache', '/doc'], :root => Gem.dir
      use Rack::Compress
      run RackRubygems.new
    }

    #webrick
    @webrick = Gem::Server.new Gem.dir, (8000 + $$ % 1000), false
    @webrick_request = WEBrick::HTTPRequest.new :Logger => nil
    @webrick_response = WEBrick::HTTPResponse.new :HTTPVersion => '1.0'
  }
  config.include Sinatra::Test
  config.include RackRubygemsTestHelpers
end
