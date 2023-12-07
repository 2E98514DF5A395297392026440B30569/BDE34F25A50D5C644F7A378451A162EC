# !/bin/bash

#获取域名填写数量
num=${#hostname[*]};

#判断优选ip数量是否大于域名数，小于则让优选数与域名数相同
[ "$CFST_DN" -le $num ] && CFST_DN=$num;
CFST_P=$CFST_DN;

# 判断工作模式
# 检测ip文件是否存在
[ ! -f "/app/config/ipv4.txt" ] && curl ${PROXY}https://raw.githubusercontent.com/XIU2/CloudflareSpeedTest/master/ip.txt -o /app/config/ipv4.txt
[ ! -f "/app/config/ipv6.txt" ] && curl ${PROXY}https://raw.githubusercontent.com/XIU2/CloudflareSpeedTest/master/ipv6.txt -o /app/config/ipv6.txt

[ "$IP_ADDR" = "ipv6" ] && echo "当前工作模式为ipv6" || echo "当前工作模式为ipv4"


  # 判断是否配置测速地址 
  [[ "$CFST_URL" == http* ]] && CFST_URL_R="-url $CFST_URL -tp $CFST_TP " || CFST_URL_R=""

  # 检查 cfcolo 变量是否为空
  [[ -n "$cfcolo" ]] && cfcolo="-cfcolo $cfcolo"

  # 检查 httping_code 变量是否为空
  [[ -n "$httping_code" ]] && httping_code="-httping-code $httping_code"

  # 检查 CFST_STM 变量是否为空
  [[ -n "$CFST_STM" ]] && CFST_STM="-httping $httping_code $cfcolo"


  # 检查是否配置反代IP
if [ "$IP_PR_IP" = "1" ] ; then
    if [[ $(cat /app/cf_ddns/.pr_ip_timestamp | jq -r ".pr1_expires") -le $(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) ]]; then

        # 获取线路1的反代ip 到/app/cf_ddns/ip.zip
        wget -O /app/cf_ddns/ip.zip ${PROXY}https://github.com/ip-scanner/cloudflare/archive/refs/heads/daily.zip &&

        # 解压到 /app/cf_ddns/ip1/
        unzip -d /app/cf_ddns/ip1 /app/cf_ddns/ip.zip > /dev/null 2>&1 &&
        mv /app/cf_ddns/ip1/cloudflare-daily/*.txt /app/cf_ddns/ip1/ &&
        cat /app/cf_ddns/ip1/*.txt >> /app/cf_ddns/pr_ip.txt &&
        rm -rf /app/cf_ddns/ip.zip /app/cf_ddns/ip1/ && echo "成功获取ip"

        echo "{\"pr1_expires\":\"$(($(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) + 86400))\"}" > /app/cf_ddns/.pr_ip_timestamp
        echo "已更新线路1的反向代理列表"
    fi
elif [ "$IP_PR_IP" = "2" ] ; then
    if [[ $(cat /app/cf_ddns/.pr_ip_timestamp | jq -r ".pr2_expires") -le $(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) ]]; then

        # 获取线路2的反代IP 到/app/cf_ddns/ip.zip
        curl https://zip.baipiao.eu.org --output /app/cf_ddns/ip.zip &&
        unzip -d /app/cf_ddns/ip2 /app/cf_ddns/ip.zip  > /dev/null 2>&1 &&
        cat /app/cf_ddns/ip2/*.txt >> /app/cf_ddns/pr_ip.txt &&
        rm -rf /app/cf_ddns/ip.zip /app/cf_ddns/ip2/ && echo "成功获取ip"

        echo "{\"pr2_expires\":\"$(($(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) + 86400))\"}" > /app/cf_ddns/.pr_ip_timestamp
        echo "已更新线路2的反向代理列表"
    fi
fi

# 测速

if [ "$IP_PR_IP" -ne "0" ] ; then
    $CloudflareST $CFST_URL_R -t $CFST_T -n $CFST_N -dn $CFST_DN -tl $CFST_TL -dt $CFST_DT -tp $CFST_TP -sl $CFST_SL -p $CFST_P -tlr $CFST_TLR $CFST_STM -f /app/cf_ddns/pr_ip.txt -o /app/cf_ddns/result.csv
elif [ "$IP_ADDR" = "ipv6" ] ; then
#开始优选IPv6
    $CloudflareST $CFST_URL_R -t $CFST_T -n $CFST_N -dn $CFST_DN -tl $CFST_TL -dt $CFST_DT -tp $CFST_TP -tll $CFST_TLL -sl $CFST_SL -p $CFST_P -tlr $CFST_TLR $CFST_STM -f /app/config/ipv6.txt -o /app/cf_ddns/result.csv
else
#开始优选IPv4
    $CloudflareST $CFST_URL_R -t $CFST_T -n $CFST_N -dn $CFST_DN -tl $CFST_TL -dt $CFST_DT -tp $CFST_TP -tll $CFST_TLL -sl $CFST_SL -p $CFST_P -tlr $CFST_TLR $CFST_STM -f /app/config/ipv4.txt -o /app/cf_ddns/result.csv
fi
echo "测速完毕";
