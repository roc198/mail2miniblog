#crontab -u root -e
# m h  dom mon dow   command
#*/1 * * * * /bin/sh /opt/hg/mail2miniblog/util/cron.sh > /opt/hg/mail2miniblog/cron.log 2>&1


count=`ps -wef|grep mail2twitter.rb |grep -v grep |wc -l`
if [ "$count" -eq 1 ]; then
  echo "The mail2twitter.rb process already run";
else
  echo "Start the mail2twitter.rb  process now:"
  nohup /usr/local/bin/ruby /opt/hg/mail2miniblog/mail2twitter.rb &
fi
