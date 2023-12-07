# !/bin/bash
#	版本：20231004
# 用于CloudflareST调用，更新hosts和更新dnspod DNS。

#set -euo pipefail
ipv4Regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])";

networks=('默认' '电信' '联通' '移动' '铁通' '广电' '教育网' '境内' '境外')
RECORD_LINE=${networks[LINE]}

if [ "$IP_TO_DNSPOD" = "1" ]; then
    # 发送请求并获取响应
    response=$(curl -sSf -X POST "https://dnsapi.cn/Domain.List" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "login_token=${dnspod_token}&format=json&offset=0&length=20")

    # 解析json响应并检查状态码
    if [[ $(echo ${response} | jq -r '.status.code') == 1 ]]; then
        echo "dnspod Token有效"
    else
        echo "dnspod Token无效"
        echo "登陆错误,检查dnspod Token信息填写是否正确！" > $informlog
        source $cf_push;
        exit 1;
    fi
       echo "dnspod Token验证成功";
else
    echo "未配置dnspod Token"
fi


update_record(){
# 开始循环
echo "正在更新域名，请稍后...";
x=0;
while [[ ${x} -lt $num ]]; do
  CDNhostname=${hostname[$x]};
  
  # 获取优选后的ip地址 
  ipAddr=$(sed -n "$((x + 2)),1p" /app/cf_ddns/result.csv | awk -F, '{print $1}');
  ipSpeed=$(sed -n "$((x + 2)),1p" /app/cf_ddns/result.csv | awk -F, '{print $6}');
  if [ $ipSpeed = "0.00" ]; then
    echo "第$((x + 1))个---$ipAddr测速为 0，跳过更新DNS，检查配置是否能正常测速！";
  elif [[ -n "$CFST_SL" ]]; then
    if [ `echo $ipSpeed < $CFST_SL | bc` -eq 1 ]; then
      echo "第$((x + 1))个---$ipAddr测速为 ${ipSpeed}，小于设定值 ${CFST_SL}，跳过更新DNS！";
    fi
  else
    if [ "$IP_TO_HOSTS" = 1 ]; then
      echo $ipAddr $CDNhostname >> /app/cf_ddns/hosts_new
    # else
      # echo "未配置hosts"
    fi
  
    if [ "$IP_TO_DNSPOD" = 1 ]; then
      echo "开始更新第$((x + 1))个---$ipAddr";
    
      # 开始DDNS
      if [[ $ipAddr =~ $ipv4Regex ]]; then
        recordType="A";
      else
        recordType="AAAA";
      fi

      # split domain and subdomain by .
      IFS='.' read -ra arr <<< "$CDNhostname"
      # count the number of elements in the array
      len=${#arr[@]}
  
      # if there is only 1 element, it means the domain is the full domain and subdomain should be "@"
      if [ $len -eq 1 ]; then
        domain="$CDNhostname"
        sub_domain="@"
      elif [ $len -eq 2 ]; then
        domain="$CDNhostname"
        sub_domain="@"
      else
        # check if the domain ends with "eu.org"
        if [ "${arr[$len-2]}.${arr[$len-1]}" = "eu.org" ]; then
          # get the domain by joining the last three elements with .
          domain="${arr[$len-3]}.${arr[$len-2]}.${arr[$len-1]}"
          # get the subdomain by joining all elements except the last three with .
          if [ $len -eq 3 ]; then
            sub_domain="@"
          else
            sub_domain="$(IFS='.'; echo "${arr[*]:0:$len-3}")"
          fi
        else
          # get the domain by joining the last two elements with .
          domain="${arr[$len-2]}.${arr[$len-1]}"
          # get the subdomain by joining all elements except the last two with .
          sub_domain="$(IFS='.'; echo "${arr[*]:0:$len-2}")"
        fi
      fi
    
      DOMAIN_NAME=$domain
      SUBDOMAIN=$sub_domain
    
      ## DNS新建与更新
      # call DNSPod API to get the domain ID and record ID
      RESPONSE=$(curl -sX POST https://dnsapi.cn/Record.List -d "login_token=$dnspod_token&format=json&domain=$DOMAIN_NAME&sub_domain=$SUBDOMAIN")

      # check if the domain exists
      STATUS=$(echo "$RESPONSE" | jq -r '.status.code')
      if [ "$STATUS" == "1" ]; then
        # extract domain ID and record ID from the API response
        RECORD_ID=$(echo "$RESPONSE" | jq -r '.records[0].id')
        #判断返回的line_id是否和设置一致
        declare -A line_id_dict=(
                ["默认"]="0"
                ["国内"]="7=0"
                ["国外"]="3=0"
                ["电信"]="10=0"
                ["联通"]="10=1"
                ["教育网"]="10=2"
                ["移动"]="10=3"
                ["百度"]="90=0"
                ["谷歌"]="90=1"
                ["搜搜"]="90=4"
                ["有道"]="90=2"
                ["必应"]="90=3"
                ["搜狗"]="90=5"
                ["奇虎"]="90=6"
                ["搜索引擎"]="80=0"
         )

        CURRENT_RECORD_LINE=$(echo "$RESPONSE" | jq -r '.records[0].line_id')

        for key in "${!line_id_dict[@]}"
        do
            if [ "${line_id_dict[$key]}" == "$CURRENT_RECORD_LINE" ]
            then
                if [ "$RECORD_LINE" == "$key" ]
                then
                   # update DNS record with the current IP address
                    RESPONSE=$(curl -sX POST https://dnsapi.cn/Record.Modify -d "login_token=$dnspod_token&format=json&domain=$DOMAIN_NAME&record_id=$RECORD_ID&sub_domain=$SUBDOMAIN&record_line=$RECORD_LINE&record_type=$recordType" -d "value=$ipAddr")
                    # check if the update was successful
                    STATUS=$(echo "$RESPONSE" | jq -r '.status.code')
                    if [ "$STATUS" == "1" ]; then
                      echo "$CDNhostname更新成功，测速为 $ipSpeed MB/s"
                    else
                      echo "$CDNhostname更新失败"
                    fi
        # 输出信息
        echo -e "
$(date "+%Y-%m-%d %H:%M:%S") 测速详情：
指定地区：${cfcolo}
        "
        cat /app/cf_ddns/result.csv
                else
                    # add DNS record for the domain
                    RESPONSE=$(curl -sX POST https://dnsapi.cn/Record.Create -d "login_token=$dnspod_token&format=json&domain=$DOMAIN_NAME&sub_domain=$SUBDOMAIN&record_line=$RECORD_LINE&record_type=$recordType" -d "value=$ipAddr")
                    # check if the creation was successful
                    STATUS=$(echo "$RESPONSE" | jq -r '.status.code')
                    if [ "$STATUS" == "1" ]; then
                      echo "$CDNhostname添加成功，测速为 $ipSpeed MB/s"
                    else
                      echo "$CDNhostname添加失败"
                    fi
        # 输出信息
        echo -e "
$(date "+%Y-%m-%d %H:%M:%S") 测速详情：
指定地区：${cfcolo}
        "
        cat /app/cf_ddns/result.csv
                fi
                break
            fi
        done
      else
        # add DNS record for the domain
        RESPONSE=$(curl -sX POST https://dnsapi.cn/Record.Create -d "login_token=$dnspod_token&format=json&domain=$DOMAIN_NAME&sub_domain=$SUBDOMAIN&record_line=$RECORD_LINE&record_type=$recordType" -d "value=$ipAddr")

        # check if the creation was successful
        STATUS=$(echo "$RESPONSE" | jq -r '.status.code')
        if [ "$STATUS" == "1" ]; then
          echo "$CDNhostname添加成功，测速为 $ipSpeed MB/s"
        else
          echo "$CDNhostname添加失败"
        fi
        # 输出信息
        echo -e "
$(date "+%Y-%m-%d %H:%M:%S") 测速详情：
指定地区：${cfcolo}
        "
        cat /app/cf_ddns/result.csv
      fi
    fi
  fi

  ((x++))
    sleep 3s;
done > $informlog
# 更新结束
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
  source /app/cf_ddns/cf_test_speed.sh
  update_record;
  update_hosts;
}
main
