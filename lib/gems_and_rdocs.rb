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
      status, headers, response = @file_server.call(env)

      if (path =~ /doc\// && !(path =~ /index\.html$/))
        body = ""; response.each { |s| body << s }
        response = body.gsub(/(<body.*\>)/,'\1<script src="/gemlist.js"></script>')
        headers["Content-Length"] = response.size.to_s
      end
    else
      env["PATH_INFO"] = old_path_info
      status, headers, response = @app.call(env)
    end
    [status, headers, response]
  end
end