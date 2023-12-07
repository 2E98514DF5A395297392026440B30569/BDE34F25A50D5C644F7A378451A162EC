# !/bin/bash
#		版本：20231004
#   用于CloudflareST调用，更新hosts和更新cloudflare DNS。
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

source /app/cf_ddns/cf_test_speed.sh

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
  
  elif [[ -n "$CFST_SL" ]]; then
    if [ $(echo "$ipSpeed < $CFST_SL" | bc) -eq 1 ]; then
      echo "第$((x + 1))个---$ipAddr测速为 ${ipSpeed}，小于设定值 ${CFST_SL}，跳过更新DNS！";
    fi
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

# 更新hosts
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
