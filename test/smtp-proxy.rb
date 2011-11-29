require 'rubygems'
require 'em-proxy'

Proxy.start(:host => "0.0.0.0", :port => 25, :debug => false) do |conn| 
  conn.server :prod, :host => "127.0.0.1", :port => 2525
  conn.server :dev,  :host => "127.0.0.1", :port => 2526
  conn.server :test, :host => "127.0.0.1", :port => 2527
  conn.on_data do |data|
    data
  end
 
  conn.on_response do |server, resp|
    resp if server == :prod
  end
end
