# !/bin/bash
# 用于CloudflareSpeedTestDDNS运行环境检测。

# github下在CloudflareSpeedTest使用ghproxy代理
PROXY=https://mirror.ghproxy.com/

CloudflareST="/app/cf_ddns/CloudflareST"
informlog="/app/cf_ddns/informlog"
cf_push="/app/cf_ddns/cf_push.sh"

# 初始化推送
[ -e ${informlog} ] && rm ${informlog}

# 检测是否配置DDNS或更新HOSTS任意一个
[[ -z ${dnspod_token} ]] && IP_TO_DNSPOD=0 || IP_TO_DNSPOD=1

[[ -z ${api_key} ]] && IP_TO_CF=0 || IP_TO_CF=1

[ "$IP_TO_HOSTS" = "true" ] && IP_TO_HOSTS=1 || IP_TO_HOSTS=0

if [ $IP_TO_DNSPOD -eq 1 ] || [ $IP_TO_CF -eq 1 ] || [ $IP_TO_HOSTS -eq 1 ]
then
  echo "配置获取成功！"
else
  echo "HOSTS和cf_ddns均未配置！！！"
  echo "HOSTS和cf_ddns均未配置！！！" > $informlog
  source $cf_push;
  exit 1;
fi
