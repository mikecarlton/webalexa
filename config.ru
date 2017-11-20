#
# Copyright (c) 2017 Mike Carlton
# Released under terms of the MIT license:
#   http://www.opensource.org/licenses/mit-license

require 'rack'
require 'rack/contrib'
require './webalexa'

use Rack::ETag
use Rack::PostBodyContentTypeParser

run Sinatra::Application
