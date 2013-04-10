var path 				= require('path');
var fs 					= require('fs');
var smtp_server			= require('./smtp_server');

process.on('uncaughtException', function(err) {
	console.error('Caught exception: ', err);
});

var pidPath = path.join(__dirname,'.pid');
fs.writeFile(pidPath, process.pid);

process.on('SIGTERM', function(){
  fs.unlink(pidPath,function(){
  	process.exit(0);
  });
});

process.title = 'mail2weibo-server';
smtp_server.run();