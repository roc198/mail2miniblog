require "rubygems"
require 'haml'
require 'twitter_oauth'
require 'erb'

client = TwitterOAuth::Client.new(
    :consumer_key => '8BMVUFdK5HhUvPafrmw9w',
    :consumer_secret =>  'dZH43hGFF1df3x3wCcBvlzAiGFPhrU0rU67nj6IeJs' ,
    :token => '42655463-GjJfLRNHjcl45XlMnnv9rk3XOsFId9h5gA2sdHbW4',
    :secret => 'TBejKH52LYDxQhzbDCjFsN39sD18QEuisi3AhZAo'
)
puts client.authorized?

tweets = client.friends_timeline

template = ERB.new <<-EOF 
	<div class="timeline">
	    <% tweets.each do |status| %>
		<p>
		    <div style="float:left; margin:5px">
			<a href="http://twitter.com/<%= status['user']['screen_name'] %>">
			    <img src="<%= status['user']['profile_image_url'] %>" width="48" height="48"/>
			</a>
		    </div>
		    <div style="">
			<a href="http://twitter.com/<%= status['user']['screen_name'] %>">@<%= status['user']['screen_name'] %></a>
			<%= status['text'] %>
		    </div>
		    <br clear="all"/>
		</p>
	    <% end %>
	</div>
EOF


begin
   body = template.result(binding)
   puts body
rescue Exception=>e
  puts e.to_str
end



