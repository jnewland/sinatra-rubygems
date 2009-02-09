require 'rubygems'
require 'sinatra/base' 
require 'yaml'
require 'zlib'
require 'erb'
require 'rubygems'
require 'rubygems/doc_manager'
require File.expand_path(File.dirname(__FILE__) + "/rack_compress")
require File.expand_path(File.dirname(__FILE__) + "/gems_and_rdocs")

class RackRubygems < Sinatra::Base

  head "/Marshal.#{Gem.marshal_version}" do
    content_type 'application/octet-stream'
    response['Content-Length'] = source_index.length.to_s
  end

  get "/Marshal.#{Gem.marshal_version}" do
    marshal(source_index)
  end

  head "/latest_specs.#{Gem.marshal_version}" do
    content_type 'application/octet-stream'
    response['Content-Length'] = latest_specs.length.to_s
  end

  get "/latest_specs.#{Gem.marshal_version}" do
    marshal(latest_specs)
  end

  head "/specs.#{Gem.marshal_version}" do
    content_type 'application/octet-stream'
    response['Content-Length'] = specs.length.to_s
  end

  get "/specs.#{Gem.marshal_version}" do
    marshal(specs)
  end

  head "/yaml.#{Gem.marshal_version}" do
    content_type 'text/plain'
    response['Content-Length'] = source_index.length.to_s
  end

  get "/yaml.#{Gem.marshal_version}" do
    content_type 'text/plain'
    yaml
  end

  def source_index
    @gem_dir = Gem.dir
    @spec_dir = File.join @gem_dir, 'specifications'
    @source_index = Gem::SourceIndex.from_gems_in @spec_dir
    response['Date'] = File.stat(@spec_dir).mtime.to_s
    @source_index.refresh!
    @source_index
  end

  def marshal(data)
    content_type 'application/octet-stream'
    Marshal.dump(data)
  end

  def latest_specs
    source_index.latest_specs.sort.map do |spec|
      platform = spec.original_platform
      platform = Gem::Platform::RUBY if platform.nil?
      [spec.name, spec.version, platform]
    end
  end

  def specs
    specs = source_index.sort.map do |_, spec|
      platform = spec.original_platform
      platform = Gem::Platform::RUBY if platform.nil?
      [spec.name, spec.version, platform]
    end
  end

  def yaml
    source_index.to_yaml
  end

end