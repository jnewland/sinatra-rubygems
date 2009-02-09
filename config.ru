LIB_PATH = File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$:.unshift LIB_PATH
require 'rack_rubygems'
use Rack::Lint
use GemsAndRdocs, :urls => ['/cache', '/doc'], :root => Gem.dir
use Rack::Compress
run RackRubygems.new