var host  = 'session.im';

var validRecipient = ['v','t','l','ping'].map(function(to){
    return to + '@' + host;
});

module.exports = {
	workerNum		: 3,
	
	host 			: host,
	validRecipient	: validRecipient,

	client_id 		: '1869125062',
	client_secret 	: 'd128d7a473c7a06ba0b84284a24c7924',
	redirect_uri	: 'http://mail2weibo.session.im/callback',

	mail_name 		: 'mail2weibo@gmail.com',
	mail_passwd		: 'mail2miniblogxxoo',

	mobile_name		: '',
	mobile_passwd	: ''
};