
# 使用轻量级的 Alpine Linux 作为基础镜像
FROM alpine:latest

# 设置环境变量，避免交互式提示
ENV LANG=en_US.UTF-8

# 安装必要的软件包
RUN apk update && apk add --no-cache \
    bash \
    curl \
    nginx \
    socat \
    unzip \
    jq \
    binutils \
    openssl \
    qrencode \
    sudo \
    lsof \
    bind-tools \
    coreutils \
    gnupg \
    grep \
    sed \
    && rm -rf /var/cache/apk/*

# 安装 acme.sh
RUN curl https://get.acme.sh | sh

# 创建工作目录
WORKDIR /app

# 拷贝入口点脚本和辅助脚本
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 创建 v2ray-agent 相关目录
RUN mkdir -p /etc/v2ray-agent/tls \
             /etc/v2ray-agent/subscribe_local/default \
             /etc/v2ray-agent/subscribe_local/clashMeta \
             /etc/v2ray-agent/subscribe_remote/default \
             /etc/v2ray-agent/subscribe_remote/clashMeta \
             /etc/v2ray-agent/subscribe/default \
             /etc/v2ray-agent/subscribe/clashMetaProfiles \
             /etc/v2ray-agent/subscribe/clashMeta \
             /etc/v2ray-agent/subscribe/sing-box \
             /etc/v2ray-agent/subscribe/sing-box_profiles \
             /etc/v2ray-agent/subscribe_local/sing-box \
             /etc/v2ray-agent/xray/conf \
             /etc/v2ray-agent/xray/reality_scan \
             /etc/v2ray-agent/xray/tmp \
             /etc/v2ray-agent/warp \
             /etc/v2ray-agent/sing-box/conf/config \
             /usr/share/nginx/html/

# 声明暴露的端口
EXPOSE 80 443

# 定义数据卷，用于持久化证书和配置
VOLUME /etc/v2ray-agent

# 设置入口点
ENTRYPOINT ["/app/entrypoint.sh"]
