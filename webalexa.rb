#
# Copyright (c) 2017 Mike Carlton
# Released under terms of the MIT license:
#   http://www.opensource.org/licenses/mit-license

require 'sinatra'

set :haml, :format => :html5

get '/' do
  send_file File.expand_path('index.html', settings.public_folder)
end

put '/do' do
  $stderr.puts "playing #{params.inspect}"
  202       # until we really do return an audio clip
end
