FROM alpine:latest

RUN apk update
RUN apk add --no-cache bash jq wget curl tar sed gawk coreutils dcron
RUN apk --update add tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*
WORKDIR /app
COPY . /app
RUN chmod +x /app/start.sh \
    chmod +x /app/cf_ddns/CloudflareST
CMD ["/bin/sh", "-c", "/app/start.sh && tail -f /dev/null"]
