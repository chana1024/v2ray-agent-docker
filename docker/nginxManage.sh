

nginxBlog() {
    echoContent skyBlue "\n[Step 6/${totalProgress}] Setting up camouflage website..."
    local randomNum=${BLOG_TEMPLATE_ID:-$(shuf -i 1-9 -n 1)}
    rm -rf "${nginxStaticPath:?}/"*
    wget -q "${wgetShowProgressStatus}" -O "${nginxStaticPath}/blog.zip" "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/fodder/blog/unable/html${randomNum}.zip"
    unzip -o "${nginxStaticPath}/blog.zip" -d "${nginxStaticPath}" >/dev/null
    rm -f "${nginxStaticPath}/blog.zip"
    echoContent green " ---> Camouflage website set up successfully."
}

handleNginx() {
    if [[ "$1" == "start" ]]; then
        if ! pgrep -f "nginx" > /dev/null; then
            echoContent green " ---> Starting Nginx..."
            nginx
            sleep 0.5
            if ! pgrep -f "nginx" > /dev/null; then
                echoContent red " ---> Nginx failed to start. Dumping config and exiting."
                nginx -t
                exit 1
            fi
        fi
    elif [[ "$1" == "stop" ]]; then
        if pgrep -f "nginx" > /dev/null; then
            echoContent green " ---> Stopping Nginx..."
            nginx -s stop
            sleep 1
        fi
    fi
}

# Copied from original script and de-interactivated
updateRedirectNginxConf() {
    local nginxH2Conf="listen 127.0.0.1:31302 http2 so_keepalive=on proxy_protocol;"
    
cat <<EOF >${nginxConfigPath}alone.conf
server {
    listen 127.0.0.1:31300;
    server_name _;
    return 403;
}

server {
    ${nginxH2Conf}
    server_name ${domain};
    root ${nginxStaticPath};
    set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;
    client_header_timeout 1071906480m;
    keepalive_timeout 1071906480m;
EOF

    if echo "${selectCustomInstallType}" | grep -q ",5,"; then
cat <<EOF >>${nginxConfigPath}alone.conf
    location /${currentPath}grpc {
        if (\$content_type !~ "application/grpc") { return 404; }
        client_max_body_size 0;
        grpc_set_header X-Real-IP \$proxy_add_x_forwarded_for;
        client_body_timeout 1071906480m;
        grpc_read_timeout 1071906480m;
        grpc_pass grpc://127.0.0.1:31301;
    }
EOF
    fi

    # The original script has more complex logic for trojangrpc, which can be added here if needed

cat <<EOF >>${nginxConfigPath}alone.conf
    location / {
        # Redirect logic for root can be placed here if REDIRECT_DOMAIN is set
        if (\$request_uri = '/') {
            return 302 ${REDIRECT_DOMAIN:-/index.html};
        }
    }
}

server {
    listen 127.0.0.1:31300 proxy_protocol;
    server_name ${domain};
    set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;
    root ${nginxStaticPath};
    location / {}
}
EOF
}

singBoxNginxConfig() {
    local port=$1
    local nginxH2Conf="listen ${port} http2 so_keepalive=on ssl;"
    local singBoxNginxSSL="ssl_certificate /etc/v2ray-agent/tls/${domain}.crt;ssl_certificate_key /etc/v2ray-agent/tls/${domain}.key;"

    if echo "${selectCustomInstallType}" | grep -q ",11,"; then
        cat <<EOF >${nginxConfigPath}sing_box_VMess_HTTPUpgrade.conf
server {
    ${nginxH2Conf}
    server_name ${domain};
    root ${nginxStaticPath};
    ${singBoxNginxSSL}
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers TLS13_AES_128_GCM_SHA256:TLS13_AES_256_GCM_SHA384:TLS13_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;
    
    location /${currentPath} {
        if (\$http_upgrade != "websocket") { return 444; }
        proxy_pass http://127.0.0.1:31306;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF
    fi
}


initTLSNginxConfig() {
    echoContent skyBlue "\n[Step 2/${totalProgress}] Initializing for TLS certificate..."
    if [[ -z "${DOMAIN}" ]]; then
        echoContent red "DOMAIN environment variable not set. It is required for TLS."
        exit 1
    fi
    domain=${DOMAIN}
    echoContent yellow "\n ---> Domain set to: ${domain}"
}
