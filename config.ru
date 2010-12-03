$:.unshift '.' 
ENV['RACK_ENV'] = "production"
require 'rubygems'
require 'main'

run Sinatra::Application

