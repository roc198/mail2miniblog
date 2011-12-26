#crontab -u root -e
# m h  dom mon dow   command
#*/1 * * * * /bin/sh /opt/hg/mail2miniblog/util/cron.sh > /opt/hg/mail2miniblog/cron.log 2>&1

count=`ps -wef|grep session.im.rb |grep -v grep |wc -l`
if [ "$count" -eq 1 ]; then
  echo "The session.im.rb process already run";
else
  echo "Start the session.im.rb  process now:"
  nohup /usr/local/bin/ruby /opt/hg/mail2miniblog/session.im.rb &
fi

count=`ps -wef|grep mail2weibo.rb |grep -v grep |wc -l`
if [ "$count" -eq 1 ]; then
  echo "The mail2weibo.rb process already run";
else
  echo "Start the mail2weibo.rb process now:"
  nohup /usr/local/bin/ruby /opt/hg/mail2miniblog/mail2weibo.rb &
fi

count=`ps -wef|grep mail2twitter.rb |grep -v grep |wc -l`
if [ "$count" -eq 1 ]; then
  echo "The mail2twitter.rb process already run";
else
  echo "Start the mail2twitter.rb  process now:"
  nohup /usr/local/bin/ruby /opt/hg/mail2miniblog/mail2twitter.rb &
fi
