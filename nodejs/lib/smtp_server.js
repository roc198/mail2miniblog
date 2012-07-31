var path = require('path');
var config = require('./config');
var simplesmtp = require("simplesmtp"), fs = require("fs");
var weibo_worker = require('./weibo_oauth2_worker');

process.on('uncaughtException', function(err) {
    console.error('Caught exception: ', err);
});

exports.startSmtpServer = function(){
    var smtp = simplesmtp.createServer({
        name : config.host,
        debug : true,
        validateRecipients : true
    });

    smtp.listen(25);

    smtp.on('validateRecipient',function(envelope, email, callback){
        if(config.validRecipient.indexOf(email) === -1){
            return callback(new Error('invalid recipient'));
        }
        callback(null);
    });

    smtp.on("startData", function(envelope){
        envelope.mailParser = weibo_worker.mailParser();
    });

    smtp.on("data", function(envelope, chunk){
        envelope.mailParser.write(chunk);
    });

    smtp.on("dataReady", function(envelope, callback){
        envelope.mailParser.end();
        mailParser = null;
        callback(null, "happy");
    });
};

exports.run = function(){
    weibo_worker.startHttpServer();

    this.startSmtpServer();
};