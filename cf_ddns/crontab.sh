#!bin/bash

# 把文件复制一份
if [ ! -f /var/spool/cron/crontabs/root.bak ]; then 
  cp /var/spool/cron/crontabs/root /var/spool/cron/crontabs/root.bak; 
fi

# 删掉原来的文件
rm /var/spool/cron/crontabs/root

# 把复制后的文件改回原文件的名字
cp /var/spool/cron/crontabs/root.bak /var/spool/cron/crontabs/root

# 写入任务计划表到"原"文件
echo "$TIMING cd /app/cf_ddns/ && bash cf_ddns.sh" >> /var/spool/cron/crontabs/root

# 执行计划任务
crond
