#!/bin/bash
# docker程序开始脚本
source /app/config/config.conf;
source /app/cf_ddns/cf_check.sh;
source /app/cf_ddns/crontab.sh;

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
source /app/cf_ddns/cf_push.sh;
#tail -f /dev/null;
exit 0;
