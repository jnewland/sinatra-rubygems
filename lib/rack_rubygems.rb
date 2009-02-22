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

  get '/' do
    specs, total_file_count = get_specs_and_file_count
    @values = { "gem_count" => specs.size.to_s, "specs" => specs,
               "total_file_count" => total_file_count.to_s }
    erb :index
  end

  get '/gemlist.js' do
    content_type 'text/javascript'
    specs, total_file_count = get_specs_and_file_count
    
    body = "document.writeln('<select style=\"float:right;margin: 10px 10px 0 0 \" onchange=\"window.parent.location=this.value\">');"
    body << "document.writeln('<option value=\"/\">Gems:</option>');"
    specs.each do |spec|
      if spec["rdoc_installed"]
        body << "document.writeln(\"<option value='#{spec['doc_path']}'>#{spec['name']} - #{spec['version']}</option>\");"
      end
    end
    body << "document.writeln('</select>');"
    body
  end

  get '/gem-server-rdoc-style.css' do
    content_type 'text/css'
    File.read File.expand_path(File.dirname(__FILE__) + "/../public/gem-server-rdoc-style.css")
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

  def get_specs_and_file_count
    specs = []
    total_file_count = 0

    source_index.each do |path, spec|
      total_file_count += spec.files.size
      deps = spec.dependencies.map do |dep|
        { "name"    => dep.name,
          "type"    => dep.type,
          "version" => dep.version_requirements.to_s, }
      end

      deps = deps.sort_by { |dep| [dep["name"].downcase, dep["version"]] }
      deps.last["is_last"] = true unless deps.empty?

      # executables
      executables = spec.executables.sort.collect { |exec| {"executable" => exec} }
      executables = nil if executables.empty?
      executables.last["is_last"] = true if executables

      specs << {
        "authors"             => spec.authors.sort.join(", "),
        "date"                => spec.date.to_s,
        "dependencies"        => deps,
        "doc_path"            => "/doc_root/#{spec.full_name}/rdoc/index.html",
        "executables"         => executables,
        "only_one_executable" => (executables && executables.size == 1),
        "full_name"           => spec.full_name,
        "has_deps"            => !deps.empty?,
        "homepage"            => spec.homepage,
        "name"                => spec.name,
        "rdoc_installed"      => Gem::DocManager.new(spec).rdoc_installed?,
        "summary"             => spec.summary,
        "version"             => spec.version.to_s,
      }
    end

    specs << {
      "authors" => "Chad Fowler, Rich Kilmer, Jim Weirich, Eric Hodel and others",
      "dependencies" => [],
      "doc_path" => "/doc_root/rubygems-#{Gem::RubyGemsVersion}/rdoc/index.html",
      "executables" => [{"executable" => 'gem', "is_last" => true}],
      "only_one_executable" => true,
      "full_name" => "rubygems-#{Gem::RubyGemsVersion}",
      "has_deps" => false,
      "homepage" => "http://rubygems.org/",
      "name" => 'rubygems',
      "rdoc_installed" => true,
      "summary" => "RubyGems itself",
      "version" => Gem::RubyGemsVersion,
    }

    specs = specs.sort_by { |spec| [spec["name"].downcase, spec["version"]] }
    specs.last["is_last"] = true

    # tag all specs with first_name_entry
    last_spec = nil
    specs.each do |spec|
      is_first = last_spec.nil? || (last_spec["name"].downcase != spec["name"].downcase)
      spec["first_name_entry"] = is_first
      last_spec = spec
    end
    return [specs, total_file_count]
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