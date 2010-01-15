require 'sinatra'
require 'json'
require 'addressable/uri'
require 'rest_client'
require File.expand_path('rack_stereoscope.rb', File.dirname(__FILE__))

configure do
  use Rack::Reloader;
  use Rack::Lint;
  use Rack::Stereoscope;
end

helpers do
  def rel(path)
    host = request.host
    port = request.port
    Addressable::URI.join("http://#{host}:#{port}", path).to_s
  end
end

get '/' do
  content_type 'application/json'
  {
    :explanation  => "A fake API to demonstrate Stereoscope",
    :twitter      => rel('/twitter'),
    :list         => rel('/list'),
    :assocations  => rel('/associations'),
    :uri_template => rel('/uri_template'),
    :tabular      => rel('/tabular')
  }.to_json
end

get '/foo/*' do 
  content_type 'application/json'
  params.to_json
end

get '/list' do
  content_type 'application/json'
  [
    "Item 1",
    "Item 2",
    "Item 3"
  ].to_json
end

get '/associations' do
  content_type 'application/json'
  {
    "foo"  => "bar",
    "baz"  => "buz"
  }.to_json
end

get '/tabular' do
  content_type 'application/json'
  [
    {
      :id             => 1,
      :name           => "Plan 9 from Outer Space",
      :date           => "1959-07-01"
    },
    {
      :id             => 2,
      :name           => "Bride of the Monster",
      :date           => "1956-05-11"
    },
    { :id             => 3,
      :name           => "Glen or Glenda",
      :date           => "1953-01-01"
    }
  ].to_json
end

get '/uri_template' do
  content_type 'application/json'
  {:uri => rel('/foo/{subpath}?param1={param1}&param2={param2}')}.to_json
end

get '/twitter' do
  content_type 'application/json'
  RestClient.get('http://twitter.com/statuses/public_timeline.json')
end
