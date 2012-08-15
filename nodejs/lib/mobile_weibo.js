var http = require('http');
var qs = require('querystring');

function parse_response(res, callback) {
  var list = [];
  res.on('data', function(chunk) {
    list.push(chunk);
  });
  res.on('end', function() {
    callback(Buffer.concat(list).toString());
    list = null;
    console.log('headers: ', JSON.stringify(res.headers, null, 3));
  });

  res.on("error", function(error) {
    console.log(error);
  });
};

exports.login = function(user, passwd, callback) {
  var post_data = qs.stringify({
    check : '1',
    backURL : '/',
    uname : user,
    pwd : passwd,
    autoLogin : '1'
  });

  var options = {
    host : 'm.weibo.cn',
    path : '/login',
    method : 'POST',
    headers : {
      'Accept' : 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language' : 'en-us,en;q=0.5',
      'Connection' : 'keep-alive',
      'DNT' : '1',
      'Host' : 'm.weibo.cn',
      'Referer' : 'http://m.weibo.cn/login',
      'User-Agent' : 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:14.0) Gecko/20100101 Firefox/14.0.1',

      'Content-Type' : 'application/x-www-form-urlencoded',
      'Content-Length' : post_data.length
    }
  };
  var req = http.request(options, function(res) {

    parse_response(res, function(data) {
      var cookies = [];
      res.headers['set-cookie'] && res.headers['set-cookie'].forEach(function(cookie, i) {
        cookies.push(cookie.split(';')[0]);
      });
      callback(data, cookies.join(';'));
    });
  });
  req.write(post_data)
  req.end();

  req.on('error', function(e) {
    console.error(e);
  });
};

exports.getUserInfo = function(cookie, callback) {
  var options = {
    host : 'm.weibo.cn',
    path : '/home/homeData?page=1&&_=1344925580812',
    method : 'GET',
    headers : {
      'cookie' : cookie,
      'Accept' : 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language' : 'en-us,en;q=0.5',
      'Connection' : 'keep-alive',
      'DNT' : '1',
      'Host' : 'm.weibo.cn',
      'Referer' : 'http://m.weibo.cn',
      'User-Agent' : 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:14.0) Gecko/20100101 Firefox/14.0.1'
    }
  };

  http.get(options, function(res) {
    parse_response(res, function(data) {
      callback(JSON.parse(data).userInfo.id);
    });
    console.log("Got response: " + res.statusCode);
  }).on('error', function(e) {
    console.log("Got error: " + e.message);
  });
};

exports.update = function(status, uid, cookie, callback) {
  var post_data = qs.stringify({
    'content' : status
  });

  var options = {
    host : 'm.weibo.cn',
    path : '/mblogDeal/addAMblog?uid=' + uid + '&st=33b2&',
    method : 'POST',
    headers : {
      'cookie' : cookie,
      'Accept' : 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language' : 'en-us,en;q=0.5',
      'Connection' : 'keep-alive',
      'DNT' : '1',
      'Host' : 'm.weibo.cn',
      'Referer' : 'http://m.weibo.cn',
      'User-Agent' : 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:14.0) Gecko/20100101 Firefox/14.0.1',

      'Content-Type' : 'application/x-www-form-urlencoded',
      'Content-Length' : post_data.length
    }
  };
  var req = http.request(options, function(res) {
    parse_response(res, callback);
  });
  req.write(post_data)
  req.end();

  req.on('error', function(e) {
    console.error(e);
  });
};