require File.expand_path(File.dirname(__FILE__) + "/spec_helper.rb")

describe "The Rack Rubygems Server" do

  it "serves a list of gems up at the root"

  it 'serves rdocs' do
    get '/doc_root/rubygems-1.3.1/rdoc/index.html'
    @response.should be_ok
  end

  it 'serves gems' do
    get '/gems/rack-0.9.1.gem'
    @response.should be_ok
  end

  it 'provides marshal data' do
    should_match_webrick_behavior "/Marshal.#{Gem.marshal_version}", :Marshal
    should_match_webrick_behavior "/Marshal.#{Gem.marshal_version}", :Marshal, :head
    @response.headers['Content-Length'].to_i.should > 0
  end

  it 'provides compressed marshal data' do
    should_match_webrick_behavior "/Marshal.#{Gem.marshal_version}.Z", :Marshal
  end

  it 'provides latest specs' do
    should_match_webrick_behavior "/latest_specs.#{Gem.marshal_version}", :latest_specs
    should_match_webrick_behavior "/latest_specs.#{Gem.marshal_version}", :latest_specs, :head
    @response.headers['Content-Length'].to_i.should > 0
  end

  it 'provides compressed latest specs' do
    should_match_webrick_behavior "/latest_specs.#{Gem.marshal_version}.gz", :latest_specs
  end

  it 'provides specs' do
    should_match_webrick_behavior "/specs.#{Gem.marshal_version}", :specs
    should_match_webrick_behavior "/specs.#{Gem.marshal_version}", :specs, :head
    @response.headers['Content-Length'].to_i.should > 0
  end

  it 'provides compressed specs' do
    should_match_webrick_behavior "/specs.#{Gem.marshal_version}.gz", :specs
  end

  it 'provides yaml' do
    should_match_webrick_behavior "/yaml.#{Gem.marshal_version}", :yaml
    should_match_webrick_behavior "/yaml.#{Gem.marshal_version}", :yaml, :head
    @response.headers['Content-Length'].to_i.should > 0
  end

  it 'provides compressed yaml' do
    should_match_webrick_behavior "/yaml.#{Gem.marshal_version}.Z", :yaml
  end

  describe "provides access to individual gemspecs" do
    it "via name and version" do
      should_match_webrick_behavior "/quick/a-1.gemspec.rz", :quick
    end

    it "via name, version, and platform" do
      a1_p = quick_gem 'a', '1' do |s| s.platform = Gem::Platform.local end
      should_match_webrick_behavior "/quick/a-1-#{Gem::Platform.local}.gemspec.rz", :quick
    end

    it "performing substring matching" do
      ab1 = quick_gem 'ab', '1'
      should_match_webrick_behavior "/quick/ab-1.gemspec.rz", :quick
    end

    it "via a quick index" do
      should_match_webrick_behavior "/quick/index", :quick
    end

    it "via a quick compressed index" do
      should_match_webrick_behavior "/quick/index.rz", :quick
    end

    it "via a quick latest index" do
      should_match_webrick_behavior "/quick/latest_index", :quick
    end

    it "via a quick compressed latest index" do
      should_match_webrick_behavior "/quick/latest_index.rz", :quick
    end

    it "returns a 404 when accessing a missing gem" do
      get "/quick/z-9.gemspec.rz"
      @response.should_not be_ok
    end

    it "marshalled via name and version" do
      should_match_webrick_behavior "/quick/Marshal.#{Gem.marshal_version}/a-1.gemspec.rz", :quick
    end

    it "marshalled via name, version, and platform" do
      should_match_webrick_behavior "/quick/Marshal.#{Gem.marshal_version}/a-1-#{Gem::Platform.local}.gemspec.rz", :quick
    end
  end

end