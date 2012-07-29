var path = require('path');
var fs = require('fs');
var express = require('express');
var weibo_api = require('./weibo_oauth2_api');
var MailParser  = require("mailparser").MailParser;
var redis = require("redis");
var client = redis.createClient();

client.on("error", function (err) {
    console.error("redis connection Error " + err);
});

process.on('uncaughtException', function(err) {
    console.error('Caught exception: ', err);
});
    
function mailParser(){
    var mailparser  = new MailParser({
        streamAttachments : true
    });

    var picPath;
    mailparser.on("attachment", function(attachment){
        if(attachment && attachment.fileName && /(.GIF|.JPEG|.JPG|.PNG)$/.test(attachment.fileName.toUpperCase())){
            picPath = "/tmp/weibo_" + attachment.generatedFileName;
            attachment.stream.pipe(fs.createWriteStream(picPath));
        }
    });

    mailparser.on("end", function(mail){ 
        var to = mail.to[0].address.replace(/@.+/,'');
        process.nextTick(function(){
            switch(to){
                case 'v':
                    if(client.connected && mail.subject){
                        var access_token = mail.subject.trim();
                        client.set(mail.from[0].address + '_oauth2', access_token,function(){
                            console.log(mail.headers.from + " authed ok!");
                        });
                    }
                    break;
                case 't':
                    client.get(mail.from[0].address + '_oauth2',function(err,token){
                        if(err){
                            throw err; 
                        }
                        if(token && mail.subject){
                            publishWeibo(token,mail.subject,picPath,function(){
                                mail.attachments && mail.attachments.forEach(function(attachment,i){
                                    fs.unlink('/tmp/weibo_' +  attachment.generatedFileName, function (err) {
                                        console.log(picPath + "  deleted.");
                                    });
                                });
                            }); 
                        }
                    });
                    break;
                case 'l':
                    //todo
                    break;
            }
        });
    });
    return mailparser;
}

function publishWeibo(token,status,picPath,cb){
    status = leftB(status,140);
    if(picPath){
        weibo_api.statuses.upload(status,picPath,token,function(json) {
            console.log(json);
            cb(json);
        });
    }else{
        weibo_api.statuses.update(status, token , function(json){
            console.log(json);
            cb(json);
        });
    }
}

function leftB(str, lens){
    var s = str.replace(/\*/g, ' ').replace(/[^\x00-\xff]/g, '**');
    str = str.slice(0, s.slice(0, lens).replace(/\*\*/g, ' ').replace(/\*/g, '').length);
    if (Math.ceil(str.replace(/[^\x00-\xff]/g,'aa').length/2) > lens && lens > 0) {
        str = str.slice(0, str.length - 1);
    }
    return str;
};

exports.mailParser =  mailParser;
exports.startServer = function(){
    weibo_api.config('1869125062', 'd128d7a473c7a06ba0b84284a24c7924', 'http://mail2weibo.session.im/callback');
    
    var app = express.createServer();
    app.use(app.router);

    app.get('/', function(req, res) {
      res.end('<a href="URI">授权使用邮件发微博</a>'.replace('URI', weibo_api.get_authorize_url()));
    });

    app.get('/callback', function(req, res) {
      var code = req.param('code', null);
      if(code) {
          weibo_api.access_token(code, function(data) {
          console.log(data);
          res.writeHead(200, {
            'Content-Type': 'text/html;charset=utf-8' 
          });
          res.end('<ul>\
                <li>绑定邮箱,请发邮件到 v@session.im (邮件 <b>主题</b> 必须为 access_token <b>邮件内容</b>可以为空)</li>\
                <li>绑定邮箱后,发邮件到 t@session.im (邮件 <b>主题</b> 即为微博内容,<b>图片附件</b>会自动发布为微博图片. <b>邮件内容</b>可以为空)即可发布微博</li>\
            <ul>'.replace('access_token',data['access_token']));
            
          // weibo_api.statuses.friends_timeline(data['access_token'], function(json){
          //   console.log(json);
          // });
        });
      }
    });
    app.listen(8888);
};
