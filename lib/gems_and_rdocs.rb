class GemsAndRdocs

  def initialize(app, options={})
    @app = app
    @urls = options[:urls]
    @file_server = Rack::File.new(options[:root])
  end

  def call(env)
    old_path_info = env["PATH_INFO"]
    env["PATH_INFO"] = env["PATH_INFO"].to_s.gsub(/^\/gems/,'/cache')
    env["PATH_INFO"] = env["PATH_INFO"].to_s.gsub(/^\/doc_root/,'/doc')
    path = env["PATH_INFO"]
    can_serve = @urls.any? { |url| path.index(url) == 0 }

    if can_serve
      @file_server.call(env)
    else
      env["PATH_INFO"] = old_path_info
      @app.call(env)
    end
  end
end