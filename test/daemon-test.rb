require 'rubygems'   
require 'daemons'

Daemons.daemonize({
    :backtrace  => true,
    :log_dir    => '/var/log',
    :log_output => true
    
})

loop {
    puts Time.now
    sleep(5)
}
  
