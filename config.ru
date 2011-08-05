$:.unshift '.' 
ENV['RACK_ENV'] = "production"
require 'rubygems'
require 'mail2miniblog-allinone'

run Sinatra::Application

