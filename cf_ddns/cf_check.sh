#!/bin/bash
#         用于CloudflareSpeedTestDDNS运行环境检测。

#github下在CloudflareSpeedTest使用ghproxy代理
PROXY=https://ghproxy.com/

CloudflareST="/app/cf_ddns/CloudflareST"
informlog="/app/cf_ddns/informlog"
cf_push="/app/cf_ddns/cf_push.sh"

# 初始化推送
if [ -e ${informlog} ]; then
  rm ${informlog}
fi

# 检测是否配置DDNS或更新HOSTS任意一个
if [[ -z ${dnspod_token} ]]; then
  IP_TO_DNSPOD=0
else
  IP_TO_DNSPOD=1
fi

if [[ -z ${api_key} ]]; then
  IP_TO_CF=0
else
  IP_TO_CF=1
fi

if [ "$IP_TO_HOSTS" = "true" ]; then
  IP_TO_HOSTS=1
else
  IP_TO_HOSTS=0
fi

if [ $IP_TO_DNSPOD -eq 1 ] || [ $IP_TO_CF -eq 1 ] || [ $IP_TO_HOSTS -eq 1 ]
then
  echo "配置获取成功！"
else
  echo "HOSTS和cf_ddns均未配置！！！"
  echo "HOSTS和cf_ddns均未配置！！！" > $informlog
  source $cf_push;
  exit 1;
fi
