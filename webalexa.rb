#
# Copyright (c) 2017 Mike Carlton
# Released under terms of the MIT license:
#   http://www.opensource.org/licenses/mit-license

require 'sinatra'
require 'oauth2'
require 'json'
require 'rack/ssl-enforcer'
require 'curb'
require 'base64'

configure :production do
  use Rack::SslEnforcer
end

# can't use "enable :session" as SslEnforcer needs to be first
set :session_secret, ENV['SESSION_SECRET']
use Rack::Session::Cookie, key: 'rack.session',
                           path: '/',
                           expire_after: 86_400 * 30,
                           secret: settings.session_secret

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
  pass if [ '/login', '/code' ].include? request.path_info

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
  @client ||= OAuth2::Client.new(ENV['CLIENT_ID'], ENV['CLIENT_SECRET'], {
                authorize_url: 'https://www.amazon.com/ap/oa',
                token_url: 'https://api.amazon.com/auth/o2/token'
              })
end

# generate an app uri
def app_uri(path = '/')
  uri = URI.parse(request.url)
  uri.path = path
  uri.query = nil
  uri.to_s
end

get '/' do
  send_file File.expand_path('index.html', settings.public_folder)
end

get '/login' do
  session[:state] = SecureRandom.hex(32)
  scope_data = { 'alexa:all' => {
                    productID: 'webalexa',
                    productInstanceAttributes: {
                      deviceSerialNumber: '1' } } }
  location = client.auth_code.authorize_url(scope: 'alexa:all',
                                            scope_data: scope_data.to_json,
                                            response_type: 'code',
                                            state: session[:state],
                                            redirect_uri: app_uri('/code'))
  redirect location
end

get '/logout' do
  %i( state access_token expires_at error_token ).each { |p| session[p] = nil }
  redirect '/'
end

get '/code' do
  if params[:state] != session[:state]
    "<h1>Invalid State</h1><p>'#{params[:state]}' did not match saved state '#{session[:state]}'</p>"
    return 401
  elsif params[:error]
    "<h1>Error</h1><p>#{params[:error_description]} (#{params[:error]})</p>"
    return 401
  end

  access_token = client.auth_code.get_token(params[:code], redirect_uri: app_uri('/code'))
  session[:access_token] = access_token.token
  session[:expires_at] = access_token.expires_at
  session[:refresh_token] = access_token.refresh_token

  # @message = "Successfully authenticated with the server"
  #
  redirect '/'
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
  response_code, content_header, body = send_clip_to_alexa(clip['data'])
  type, content_type, parameters = parse_content_type(content_header)

  if type == 'multipart'
    parts = parse_multipart_mime(parameters, body)
    parts.find { |part| part.content_type == 'audio/mpeg' }.tap do |part|
      body = part.body
      content_type = part.content_type
    end
  end

  headers['Content-Type'] = content_type
  [ response_code, body ]
end

RECOGNIZE_URL = 'https://access-alexa-na.amazon.com/v1/avs/speechrecognizer/recognize'
def send_clip_to_alexa(data)
  curl = Curl::Easy.new(RECOGNIZE_URL) do |http|
    http.multipart_form_post = true
    http.headers['Authorization'] = 'Bearer %s' % session[:access_token]
  end

  body = {
    messageHeader: {
      deviceContext: [
        {
          name: 'playbackState',
          namespace: 'AudioPlayer',
          payload: {
            streamId: '',
            offsetInMilliseconds: 0,
            playerActivity: 'IDLE'
          }
        }
      ]
    },
    messageBody: {
      profile: 'alexa-close-talk',
      locale: 'en-us',
      format: 'audio/L16; rate=16000; channels=1'
    }
  }

  curl.http_post(Curl::PostField.content('request', body.to_json, 'application/json'),
                 Curl::PostField.content('audio', Base64.decode64(data), 'audio/L16; rate=16000; channels=1'))

  return curl.response_code, curl.content_type, curl.body
end

MimePart = Struct.new(:content_type, :parameters, :headers, :body)

# returns type (multipart), content type (multipart/mixed) and array
# of parameter fields (boundary=abcd)
def parse_content_type(content_header)
  content_fields = content_header.split(%r{;\s*})
  content_type = content_fields.shift
  type, subtype = content_type.split('/')
  [ type, content_type, content_fields ]
end

# discards preamble (before first boundary) and returns an array of MimePart's
LINE_REGEXP = %r{^[^\r]*\r\n}
HEADER_REGEXP = %r{:\s*}
def parse_multipart_mime(parameters, data)
  boundary = parameters.select { |f| f =~ /^boundary/i }.first
  boundary = boundary.split('=', 2).last

  sections = data.split(%r{(?:\r\n)?--#{boundary}(?:--)?\r\n})
  sections.shift     # ignore the preamble (part before first boundary)

  sections.map do |s|
    part = MimePart.new('text/plain', [ ], { })
    line = s.slice!(LINE_REGEXP).chomp
    while !line.empty?
      field, value = line.split(HEADER_REGEXP, 2)
      field.downcase!
      part.headers[field] = value
      part.content_type = value if field == 'content-type'
      line = s.slice!(LINE_REGEXP).chomp
    end
    part.body = s
    part
  end
end

