#!/bin/bash
# 计划任务执行脚本

source /app/config/config.conf;
source /app/cf_ddns/cf_check.sh;

case $DNS_PROVIDER in
    1)
        source /app/cf_ddns/cf_ddns_cloudflare.sh
        ;;
    2)
        source /app/cf_ddns/cf_ddns_dnspod.sh
        ;;
    *)
        echo "未选择任何DNS服务商"
        ;;
esac
source ./cf_ddns/cf_push.sh;
#tail -f /dev/null;
exit 0;
