var simplesmtp = require("simplesmtp"), fs = require("fs");
var weibo_worker = require('./weibo_oauth2_worker');

weibo_worker.startServer();

var host = 'session.im';
var validRecipient = ['v','t','l'].map(function(to){
    return to + '@' + host;
});

var smtp = simplesmtp.createServer({
    name : host,
    debug : true,
    validateRecipients : true
});
smtp.listen(25);

smtp.on('validateRecipient',function(envelope, email, callback){
    if(validRecipient.indexOf(email) === -1){
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
