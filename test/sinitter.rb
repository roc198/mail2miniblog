#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'twitter_oauth'
require 'yaml'

@@config = YAML.load_file("config.yml")
enable :sessions
set :run ,true
set :port, 6789
set :environment, :production
set :logging, true


get '/connect' do
  @@client = TwitterOAuth::Client.new(
    :consumer_key =>  @@config['consumer_key'],
    :consumer_secret =>  @@config['consumer_secret']
  )
  request_token = @@client.request_token(
    :oauth_callback =>  @@config['callback_url']
  )
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url + "&oauth_callback=#{CGI.escape('http://127.0.0.1:6789/auth')}" 
end

get '/auth' do
  puts params[:oauth_verifier] 
  # Exchange the request token for an access token.
  begin
    access_token = @@client.authorize(
      session[:request_token],
      session[:request_token_secret],
      :oauth_verifier => params[:oauth_verifier]
    )
  rescue OAuth::Unauthorized
	puts 'error-----------'
  end
  if @@client.authorized?
      session[:access_token] = access_token.token
      session[:secret_token] = access_token.secret
      puts "authorized! access_token=#{access_token.token} and access_secret_token=#{access_token.secret}"
      "authorized! access_token=#{access_token.token} and access_secret_token=#{access_token.secret}"
  end
end


