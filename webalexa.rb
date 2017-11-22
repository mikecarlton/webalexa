#
# Copyright (c) 2017 Mike Carlton
# Released under terms of the MIT license:
#   http://www.opensource.org/licenses/mit-license

require 'sinatra'
require 'oauth2'
require 'json'

enable :sessions
set :sessions, expire_after: 86_400*30

set :haml, :format => :html5

if settings.environment == :development
   require 'byebug'
   require 'byebug/core'
   port = ENV['BYEBUG_PORT'] || 4242
   $stderr.puts "Starting byebug server, connect with: byebug -R localhost:#{port}"
   Byebug.start_server 'localhost', port
end

before do
=begin
  pass if request.path_info == '/login'

  if !session[:user]
    session[:user] = SecureRandom.hex(32)
  end

  if !session[:refresh_token]
    redirect '/login'
  elsif !session[:access_token]
    refresh_access_token
  end
=end
end

def client
  cached ||= OAuth2::Client.new(ENV['CLIENT_ID'], ENV['CLIENT_SECRET'], {
                authorize_url: 'https://www.amazon.com/ap/oa',
                token_url: 'https://api.amazon.com/auth/o2/token'
              })
end

def redirect_uri
  uri = URI.parse(request.url)
  puts $stderr.puts $uri.scheme, $uri.to_s
  uri.path = '/code'
  uri.query = nil
  uri.to_s
end

get '/' do
  send_file File.expand_path('index.html', settings.public_folder)
end

get '/login' do
  mac = `ifconfig | grep ether | head -1` || '1'
  mac.gsub!(/ether|\s+/, '')
  session[:state] = SecureRandom.hex(32)
  scope_data = { 'alexa:all' => {
                    productID: 'webalexa',
                    productInstanceAttributes: {
                      deviceSerialNumber: '1234' } } }
  location = client.auth_code.authorize_url(scope: 'alexa:all',
                                            scope_data: scope_data.to_json,
                                            response_type: 'code',
                                            state: session[:state],
                                            redirect_uri: redirect_uri)
  $stderr.puts location

  redirect location
end

# error response
#   error_description=Access+not+permitted.
#   state=<state>
#   error=access_denied
get '/code' do
  $stderr.puts "CODE CALLBACK": params.inspect

  access_token = client.auth_code.get_token(params[:code], redirect_uri: redirect_uri)
  session[:access_token] = access_token.token
  @message = "Successfully authenticated with the server"
  @access_token = session[:access_token]

  # parsed is a handy method on an OAuth2::Response object that will 
  # intelligently try and parse the response.body
  @email = access_token.get('https://www.googleapis.com/userinfo/email?alt=json').parsed
  erb :success
end

put '/do' do
  # File is javascript so we can load in browser easily (for playing)
  data = File.read(File.expand_path('js/clips.js', settings.public_folder))

  # we make it valid json so we can easily load same data here
  data.sub!(/^[^\[]*/, '')    # remove leading "clips = "
  clips = JSON.parse(data)

  id = Integer(params['clip_id']) rescue nil
  if !id || id < 0 || id >= clips.length
    return 404
  end

  clip = clips[id]
  $stderr.puts "playing clip #{clip['label']}"

  202       # until we really do return an audio clip
end
