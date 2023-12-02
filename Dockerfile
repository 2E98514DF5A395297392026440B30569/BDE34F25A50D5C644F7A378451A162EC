FROM alpine:latest

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && apk update \
 && apk add --no-cache bash jq wget curl unzip tar sed gawk coreutils dcron

RUN apk --update add tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*

WORKDIR /app
COPY . /app
RUN chmod +x /app/start.sh \
 && chmod +x /app/cf_ddns/CloudflareST
CMD ["/bin/sh", "-c", "/app/start.sh && tail -f /dev/null"]
