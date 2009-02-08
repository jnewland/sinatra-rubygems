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
  end

  it 'provides compressed marshal data' do
    should_match_webrick_behavior "/Marshal.#{Gem.marshal_version}.Z", :Marshal
  end

  it 'provides latest specs' do
    should_match_webrick_behavior "/latest_specs.#{Gem.marshal_version}", :latest_specs
    should_match_webrick_behavior "/latest_specs.#{Gem.marshal_version}", :latest_specs, :head
  end

  it 'provides compressed latest specs' do
    should_match_webrick_behavior "/latest_specs.#{Gem.marshal_version}.gz", :latest_specs
  end

  it 'provides specs' do
    should_match_webrick_behavior "/specs.#{Gem.marshal_version}", :specs
    should_match_webrick_behavior "/specs.#{Gem.marshal_version}", :specs, :head
  end

  it 'provides compressed specs' do
    should_match_webrick_behavior "/specs.#{Gem.marshal_version}.gz", :specs
  end

  it 'provides yaml' do
    should_match_webrick_behavior "/yaml.#{Gem.marshal_version}", :yaml
    should_match_webrick_behavior "/yaml.#{Gem.marshal_version}", :yaml, :head
  end

  it 'provides compressed yaml' do
    should_match_webrick_behavior "/yaml.#{Gem.marshal_version}.Z", :yaml
  end

  describe "provides access to individual gemspecs" do
    it "via name and version"
    it "via name, version, and platform"
    it "performing substring matching"
    it "and a quick index"
    it "and a quick compressed index"
    it "and a latest index"
    it "and a compressed latest index"
    it "returns a 404 when accessing a missing gem"
    it "marshalled via name and version"
    it "marshalled via name, version, and platform"
  end

end