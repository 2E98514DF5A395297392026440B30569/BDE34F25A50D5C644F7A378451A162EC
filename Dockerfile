FROM alpine:latest

COPY . /app
WORKDIR /app

# 换源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk update && \
    apk add --no-cache bash bc jq wget curl unzip tar sed gawk coreutils dcron tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata && \
    rm -rf /var/cache/apk/* && \
    chmod +x /app/cf_ddns/CloudflareST && \
    chmod +x /app/start.sh

CMD ["/bin/sh", "-c", "/app/start.sh && tail -f /dev/null"]
