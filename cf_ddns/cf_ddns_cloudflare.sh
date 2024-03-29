# !/bin/bash
#		版本：20231004
#   用于CloudflareST调用，更新hosts和更新cloudflare DNS。
check_prepare(){
  ipv4Regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])";

  #获取空间id
  zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$(echo ${hostname[0]} | cut -d "." -f 2-)" -H "X-Auth-Email: $x_email" -H "X-Auth-Key: $api_key" -H "Content-Type: application/json" | jq -r '.result[0].id' )

  if [ "$IP_TO_CF" = "1" ]; then
    # 验证cf账号信息是否正确
    res=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json");
    resSuccess=$(echo "$res" | jq -r ".success");
    if [[ $resSuccess != "true" ]]; then
      echo "登陆错误，检查cloudflare账号信息填写是否正确!"
      echo "登陆错误，检查cloudflare账号信息填写是否正确!" > $informlog
      source $cf_push;
      exit 1;
    fi
    echo "Cloudflare账号验证成功";
  else
    echo "未配置Cloudflare账号"
  fi

  # 获取域名填写数量
  num=${#hostname[*]};

  # 判断优选ip数量是否大于域名数，小于则让优选数与域名数相同
  [ "$CFST_DN" -le $num ] && CFST_DN=$num;

  CFST_P=$CFST_DN;
}
check_model(){
  # 判断工作模式
  # 检测ip文件是否存在
  [ ! -f "/app/config/ipv4.txt" ] && curl ${PROXY}https://raw.githubusercontent.com/XIU2/CloudflareSpeedTest/master/ip.txt -o /app/config/ipv4.txt
  [ ! -f "/app/config/ipv6.txt" ] && curl ${PROXY}https://raw.githubusercontent.com/XIU2/CloudflareSpeedTest/master/ipv6.txt -o /app/config/ipv6.txt
  
  [ "$IP_ADDR" = "ipv6" ] && echo "当前工作模式为ipv6" || echo "当前工作模式为ipv4"
}

check_path(){
  # 判断是否配置测速地址 
  [[ "$CFST_URL" == http* ]] && CFST_URL_R="-url $CFST_URL -tp $CFST_TP " || CFST_URL_R=""

  # 检查 cfcolo 变量是否为空
  [[ -n "$cfcolo" ]] && cfcolo="-cfcolo $cfcolo"

  # 检查 httping_code 变量是否为空
  [[ -n "$httping_code" ]] && httping_code="-httping-code $httping_code"

  # 检查 CFST_STM 变量是否为空
  [[ -n "$CFST_STM" ]] && CFST_STM="-httping $httping_code $cfcolo"
}

get_proxyip(){
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
}

test_speed(){
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
}

update_record(){
  # 开始循环
  echo "正在更新域名，请稍后..."

  x=0
  while [[ ${x} -lt $num ]]; do
    CDNhostname=${hostname[$x]}
    
    # 获取优选后的ip地址
    ipAddr=$(sed -n "$((x + 2)),1p" /app/cf_ddns/result.csv | awk -F, '{print $1}');
    # 获取优选后的ip速度
    ipSpeed=$(sed -n "$((x + 2)),1p" /app/cf_ddns/result.csv | awk -F, '{print $6}');
    
    if [ $ipSpeed = "0.00" ]; then
      echo "第$((x + 1))个---$ipAddr测速为$ipSpeed，跳过更新DNS，检查配置是否能正常测速！";
    else
    
    # --是否同步更新到hosts
      [ "$IP_TO_HOSTS" = 1 ] && echo $ipAddr $CDNhostname >> /app/cf_ddns/hosts_new

      if [ "$IP_TO_CF" = 1 ]; then
        echo "开始更新第$((x + 1))个---$ipAddr"

        # 开始DDNS，判断ip类型
        [[ $ipAddr =~ $ipv4Regex ]] && recordType="A" || recordType="AAAA"

        listDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=${recordType}&name=${CDNhostname}"
        createDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"

        # 关闭小云朵
        proxy="false"
    
        res=$(curl -s -X GET "$listDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json")
        recordId=$(echo "$res" | jq -r ".result[0].id")
        recordIp=$(echo "$res" | jq -r ".result[0].content")
    
        if [[ $recordIp = "$ipAddr" ]]; then
          echo "更新失败，获取最快的IP与云端相同"
          resSuccess=false
        elif [[ $recordId = "null" ]]; then
          res=$(curl -s -X POST "$createDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$CDNhostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
          resSuccess=$(echo "$res" | jq -r ".success")
        else
          updateDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${recordId}"
          res=$(curl -s -X PUT "$updateDnsApi"  -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$CDNhostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
          resSuccess=$(echo "$res" | jq -r ".success")
        fi
    
        [[ $resSuccess = "true" ]] && echo "$CDNhostname更新成功，测速为 $ipSpeed MB/s" || echo "$CDNhostname更新失败"
        # 输出信息
        echo -e "
$(date "+%Y-%m-%d %H:%M:%S") 测速详情：
指定地区：${cfcolo}
        "
        cat /app/cf_ddns/result.csv
      fi
    fi
    x=$((x + 1))
    sleep 3s
  done > $informlog
}

update_hosts(){
  if [ "$IP_TO_HOSTS" = 1 ]; then
    if [ ! -f "/etc/hosts.old_cfstddns_bak" ]; then
      cp /etc/hosts /etc/hosts.old_cfstddns_bak
      cat /app/cf_ddns/hosts_new >> /etc/hosts
    else
      rm /etc/hosts
      cp /etc/hosts.old_cfstddns_bak /etc/hosts
      cat /app/cf_ddns/hosts_new >> /etc/hosts
      echo "hosts已更新"
      echo "hosts已更新" >> $informlog
      rm /app/cf_ddns/hosts_new
    fi
  fi
}
main(){
  check_prepare;
  check_model;
  check_path;
  get_proxyip;
  test_speed;
  update_record;
  update_hosts;
}
main
