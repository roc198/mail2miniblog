require "rubygems"
require "twitter"
require 'socksify'

#ssh -D 9999  myself@session.im
TCPSocket::socks_server = "127.0.0.1"
TCPSocket::socks_port = 9999

Twitter.configure do |config|
  config.consumer_key = '8BMVUFdK5HhUvPafrmw9w'
  config.consumer_secret = 'dZH43hGFF1df3x3wCcBvlzAiGFPhrU0rU67nj6IeJs'
  config.oauth_token = '42655463-GjJfLRNHjcl45XlMnnv9rk3XOsFId9h5gA2sdHbW4'
  config.oauth_token_secret = 'TBejKH52LYDxQhzbDCjFsN39sD18QEuisi3AhZAo'
end

Twitter.update("I'm tweeting with twitter gem!")

puts Twitter.home_timeline.first.text

