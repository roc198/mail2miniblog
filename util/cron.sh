#crontab -u root -e
# m h  dom mon dow   command
#*/2 * * * * /bin/sh /opt/hg/mail2miniblog/util/cron.sh > /opt/hg/mail2miniblog/cron.log 2>&1

i=`ps -wef|grep sub2.rb |grep -v grep |wc -l`
if [ "$i" -eq 1 ]; then
  echo "The sub2.rb process already run";
else
  echo "Start the sub2.rb process now:"
  nohup /usr/local/bin/ruby /opt/hg/mail2miniblog/sub2.rb &
fi

c=`ps -wef|grep em-smtp-server.rb |grep -v grep |wc -l`
if [ "$c" -eq 1 ]; then
  echo "The em-smtp-server.rb process already run";
else
  echo "Start the em-smtp-server.rb process now:"
  nohup /usr/local/bin/ruby /opt/hg/mail2miniblog/em-smtp-server.rb &
fi
