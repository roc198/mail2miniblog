#crontab -u root -e
# m h  dom mon dow   command
#每2分钟检查一次进程是否还活着，死了就重启。
#*/2 * * * * /bin/sh /opt/hg/mail2miniblog/util/cron.sh > /opt/hg/mail2miniblog/cron.log 2>&1

count=`ps -wef|grep mail2miniblog-allinone.rb |grep -v grep |wc -l`
if [ "$count" -eq 1 ]; then
  echo "The mail2miniblog-allinone.rb process already run";
else
  echo "Start the mail2miniblog-allinone.rb process now:"
  nohup /usr/local/bin/ruby /opt/hg/mail2miniblog/mail2miniblog-allinone.rb &
fi