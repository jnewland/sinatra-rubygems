require 'zlib'
require 'stringio'
module Rack
  class Compress

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      case request.path_info
      when /\.Z$/
        env["PATH_INFO"] = env["PATH_INFO"].to_s.gsub(/\.Z$/,'')
        status, headers, response = @app.call(env)
        response = deflate(response)
        headers['Content-Type'] = 'application/x-deflate'
        headers['Content-Length'] = response.length.to_s
      when /\.gz$/
        env["PATH_INFO"] = env["PATH_INFO"].to_s.gsub(/\.gz$/,'')
        status, headers, response = @app.call(env)
        response = gzip(response)
        headers['Content-Type'] = 'application/x-gzip'
        headers['Content-Length'] = response.length.to_s
      else
        status, headers, response = @app.call(env)
      end
      [status, headers, response]
    end

    def gzip(response)
      zipped = StringIO.new
      Zlib::GzipWriter.wrap zipped do |io|
        io.write response
      end
      zipped.string
    end

    def deflate(response)
      body = ''
      response.each{ |s| body << s }
      Zlib::Deflate.deflate body
    end

  end
end