var ejs = require('ejs');
var nodemailer = require("nodemailer");
var path = require('path');
var fs = require('fs');
var express = require('express');
var weibo_api = require('./weibo_oauth2_api');
var MailParser  = require("mailparser").MailParser;
var redis = require("redis");
var client = redis.createClient();

var config = require('./config');
var mobileWeibo = require('./mobile_weibo');


client.on("error", function (err) {
    console.error("redis connection Error " + err);
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
                    console.log(mail.from[0].address);
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
                    client.get(mail.from[0].address + '_oauth2',function(err,token){
                        if(err){
                            throw err; 
                        }
                        if(token){
                            friendsTimeline(token,mail.from[0].address);
                        }
                    });
                    break;
                case 'ping':
                    //monit the smtp server
                    sendMail(mail.from[0].address,'pong','pong');
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
function friendsTimeline(token,recipient){
    weibo_api.statuses.friends_timeline(token, function(json){
        console.log(json);
        if(json && json.statuses){
            sendMail(recipient,ejs.render(fs.readFileSync(path.join(__dirname,'views/friends_timeline.ejs') ,'utf8'),json));
        }
    });
}

function sendMail(to,html,text){
    text = text || '';
    var smtpTransport = nodemailer.createTransport("SMTP",{
        service: "Gmail",
        auth: {
            user: config.mail_name,
            pass: config.mail_passwd
        }
    });

    var mailOptions = {
        from: "mail2weibo@gmail.com", 
        to: to, 
        subject: "friends timeline via mail2weibo", 
        text: text, 
        html: html 
    }

    smtpTransport.sendMail(mailOptions, function(error, response){
        if(error){
            console.log(error);
        }else{
            console.log("Message sent: " + response.message);
        }
        smtpTransport.close();
    });
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
exports.startHttpServer = function(){
    weibo_api.config(config.client_id, config.client_secret, config.redirect_uri);
    
    var app = express.createServer();
    app.use(app.router);

    app.get('/', function(req, res) {
      res.writeHead(200, {
         'Content-Type': 'text/html;charset=utf-8'
      });
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
                <li>绑定邮箱后,发邮件到 l@session.im (邮件 <b>主题</b> 和 <b>邮件内容</b>均可以为空)即可查看微博feed列表(friends timeline)</li>\
            <ul>'.replace('access_token',data['access_token']));
        });
      }
    });
    app.listen(8888);
};
