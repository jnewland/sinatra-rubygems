require 'rubygems'
require 'sinatra/base' 
require 'yaml'
require 'zlib'
require 'erb'
require 'rubygems'
require File.expand_path(File.dirname(__FILE__) + "/rack_compress")
require File.expand_path(File.dirname(__FILE__) + "/gems_and_rdocs")

class RackRubygems < Sinatra::Base

  get '/' do
    @gems = Dir["#{Gem.dir}/doc/*"].sort
    erb :index
  end

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

  get '/quick/index' do
    content_type 'text/plain'
    source_index.map { |name,| name }.sort.join("\n")
  end

  get '/quick/index.rz' do
    content_type 'application/x-deflate'
    Gem.deflate(source_index.map { |name,| name }.sort.join("\n"))
  end

  get "/quick/latest_index" do
    content_type 'text/plain'
    source_index.latest_specs.map { |spec| spec.full_name }.sort.join("\n")
  end

  get "/quick/latest_index.rz" do
    content_type 'application/x-deflate'
    Gem.deflate(source_index.latest_specs.map { |spec| spec.full_name }.sort.join("\n"))
  end

  get "/quick/Marshal.#{Gem.marshal_version}/*.gemspec.rz" do
    Gem.deflate(marshal(quick(params[:splat].first), 'application/x-deflate'))
  end

  get "/quick/*.gemspec.rz" do
    content_type 'application/x-deflate'
    Gem.deflate(quick(params[:splat].first).to_yaml)
  end

  def source_index
    return @source_index if @source_index
    @gem_dir = Gem.dir
    @spec_dir = File.join @gem_dir, 'specifications'
    @source_index = Gem::SourceIndex.from_gems_in @spec_dir
    response['Date'] = File.stat(@spec_dir).mtime.to_s
    @source_index.refresh!
    @source_index
  end

  def quick(selector)
    source_index
    return unless selector =~ /(.*?)-([0-9.]+)(-.*?)?/
    name, version, platform = $1, $2, $3
    specs = source_index.search Gem::Dependency.new(name, version)

    if platform
      platform = Gem::Platform.new platform.sub(/^-/, '')
    else
      platform = Gem::Platform::RUBY
    end

    specs = specs.select { |s| s.platform == platform }

    if specs.empty?
      content_type 'text/plain'
      not_found "No gems found matching #{selector}"
    elsif specs.length > 1
      content_type 'text/plain'
      error 500, "Multiple gems found matching #{selector}"
    else
      specs.first
    end
  end

  def marshal(data, type = 'application/octet-stream')
    content_type type
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