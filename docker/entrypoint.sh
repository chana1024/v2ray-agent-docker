#!/usr/bin/env bash
#
# This script is a non-interactive adaptation of the v2ray-agent install.sh script
# for use within a Docker container. All configuration is handled via environment variables.
# This is the "full protocol" version.
#
# Original Author: mack-a
# Dockerization by: Gemini
#

# --- START OF FULLY ADAPTED FUNCTIONS FROM install.sh ---

# Most functions are copied from the original script and de-interactivated.
# All `read` prompts are replaced with environment variable checks.
# Menu-driven logic and post-install management functions are removed.

# Section: Initial Setup & Utilities
# -------------------------------------------------------------
export LANG=en_US.UTF-8

echoContent() {
    case $1 in
    "red")
        echo -e "\033[31m$2 \033[0m"
        ;;
    "skyBlue")
        echo -e "\033[1;36m$2 \033[0m"
        ;;
    "green")
        echo -e "\033[32m$2 \033[0m"
        ;;
    "yellow")
        echo -e "\033[33m$2 \033[0m"
        ;;
    *)
        echo -e "$2"
        ;;
    esac
}

checkSystem() {
    release="debian"
    installType='apt -y install'
    upgrade="apt update"
    removeType='apt -y autoremove'
    nginxConfigPath=/etc/nginx/conf.d/
    nginxStaticPath=/usr/share/nginx/html/
}

checkCPUVendor() {
    case "$(uname -m)" in
    'amd64' | 'x86_64')
        xrayCoreCPUVendor="Xray-linux-64"
        singBoxCoreCPUVendor="-linux-amd64"
        ;;
    'armv8' | 'aarch64')
        cpuVendor="arm"
        xrayCoreCPUVendor="Xray-linux-arm64-v8a"
        singBoxCoreCPUVendor="-linux-arm64"
        ;;
    *)
        echoContent red "Unsupported CPU architecture: $(uname -m)"
        exit 1
        ;;
    esac
}

initVar() {
    echoType='echo -e'
    domain=${DOMAIN}
    totalProgress=10
    coreInstallType=${CORE_TYPE}
    selectCustomInstallType=",${INSTALL_PROTOCOLS},"
    configPath=
    nginxConfigPath=/etc/nginx/conf.d/
    nginxStaticPath=/usr/share/nginx/html/
    
    # SSL
    sslType=${SSL_TYPE:-letsencrypt}
    cfAPIToken=${CF_API_TOKEN}
    sslEmail=${SSL_EMAIL}
    
    # User
    customUUID=${UUID}
    customEmail=${USER_EMAIL}
    
    # Ports (will be populated by functions)
    port=${PORT:-443}
    realityPort=${REALITY_PORT}
    xHTTPort=${XHTTP_PORT}
    hysteriaPort=${HYSTERIA_PORT}
    tuicPort=${TUIC_PORT}
    singBoxVLESSVisionPort=${VLESS_VISION_PORT}
    singBoxVLESSWSPort=${VLESS_WS_PORT}
    singBoxVMessWSPort=${VMESS_WS_PORT}
    singBoxTrojanPort=${TROJAN_PORT}
    singBoxNaivePort=${NAIVE_PORT}
    singBoxVMessHTTPUpgradePort=${VMESS_HTTPUPGRADE_PORT}
    singBoxVLESSRealityVisionPort=${REALITY_PORT} # Use the same reality port var
    singBoxVLESSRealityGRPCPort=${REALITY_GRPC_PORT}

    # Path
    customPath=${CUSTOM_PATH}
    
    # Hysteria
    hysteria2ClientDownloadSpeed=${HYSTERIA2_DOWN_MBPS:-100}
    hysteria2ClientUploadSpeed=${HYSTERIA2_UP_MBPS:-50}

    # Tuic
    tuicAlgorithm=${TUIC_ALGORITHM:-bbr}
    
    wgetShowProgressStatus="--show-progress"
}

# Section: Installation & System Tools
# -------------------------------------------------------------
mkdirTools() {
    mkdir -p /etc/v2ray-agent/tls
    mkdir -p /etc/v2ray-agent/xray/conf
    mkdir -p /etc/v2ray-agent/sing-box/conf/config
    mkdir -p /usr/share/nginx/html/
    mkdir -p /tmp/v2ray-agent-tls
}

installNginxTools() {
    apt-get update >/dev/null 2>&1
    apt-get install -y nginx >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echoContent red "Failed to install Nginx."
        exit 1
    fi
    echo "daemon off;" >> /etc/nginx/nginx.conf
}

installTools() {
    echoContent skyBlue "\n[Step 1/${totalProgress}] Installing required tools..."
    
    if ! command -v nginx &> /dev/null; then
        echoContent green " ---> Installing nginx"
        installNginxTools
    fi

    if [[ ! -d "$HOME/.acme.sh" ]] && [[ ! "${INSTALL_PROTOCOLS}" =~ "7" && -z "${INSTALL_PROTOCOLS//,/}" ]]; then
        echoContent green " ---> Installing acme.sh"
        if [[ -z "${SSL_EMAIL}" ]]; then
            echoContent red "SSL_EMAIL env var is required for acme.sh installation."
            exit 1
        fi
        curl -s https://get.acme.sh | sh -s "email=${SSL_EMAIL}" >/etc/v2ray-agent/tls/acme.log 2>&1
        if [[ $? -ne 0 ]]; then
            echoContent red "acme.sh installation failed. Check log at /etc/v2ray-agent/tls/acme.log"
            exit 1
        fi
    fi
}

installXray() {
    echoContent skyBlue "\n[Step 4/${totalProgress}] Installing Xray-core..."
    local prereleaseStatus=false
    
    version=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=5" | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
    echoContent green " ---> Xray-core version: ${version}"
    
    wget -c -q "${wgetShowProgressStatus}" -O "/tmp/xray.zip" "https://github.com/XTLS/Xray-core/releases/download/${version}/${xrayCoreCPUVendor}.zip"
    unzip -o "/tmp/xray.zip" -d /etc/v2ray-agent/xray >/dev/null
    rm -f "/tmp/xray.zip"
    
    version=$(curl -s https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest | jq -r '.tag_name')
    echoContent green " ---> Downloading geo files version: ${version}"
    wget -c -q "${wgetShowProgressStatus}" -O /etc/v2ray-agent/xray/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat"
    wget -c -q "${wgetShowProgressStatus}" -O /etc/v2ray-agent/xray/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat"
    
    chmod +x /etc/v2ray-agent/xray/xray
    ctlPath=/etc/v2ray-agent/xray/xray
    echoContent green " ---> Xray-core installed successfully."
}

installSingBox() {
    echoContent skyBlue "\n[Step 4/${totalProgress}] Installing sing-box..."
    local prereleaseStatus=false
    
    version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases?per_page=20" | jq -r ".[]|select (.prerelease==${prereleaseStatus})|.tag_name" | head -1)
    echoContent green " ---> sing-box version: ${version}"
    
    wget -c -q "${wgetShowProgressStatus}" -O "/tmp/singbox.tar.gz" "https://github.com/SagerNet/sing-box/releases/download/${version}/sing-box-${version/v/}${singBoxCoreCPUVendor}.tar.gz"
    
    tar -zxf "/tmp/singbox.tar.gz" -C "/tmp/"
    mv "/tmp/sing-box-${version/v/}${singBoxCoreCPUVendor}/sing-box" /etc/v2ray-agent/sing-box/sing-box
    
    rm -rf /tmp/sing-box*
    chmod +x /etc/v2ray-agent/sing-box/sing-box
    ctlPath=/etc/v2ray-agent/sing-box/sing-box
    echoContent green " ---> sing-box installed successfully."
}

# Section: Configuration (TLS, Nginx, Core Logic)
# -------------------------------------------------------------
initTLSNginxConfig() {
    echoContent skyBlue "\n[Step 2/${totalProgress}] Initializing for TLS certificate..."
    if [[ -z "${DOMAIN}" ]]; then
        echoContent red "DOMAIN environment variable not set. It is required for TLS."
        exit 1
    fi
    domain=${DOMAIN}
    echoContent yellow "\n ---> Domain set to: ${domain}"
}

acmeInstallSSL() {
    local acme_domain="${domain}"
    local dns_api_params=""
    
    if [[ "${USE_WILDCARD_CERT}" == "y" ]]; then
        dnsTLSDomain=$(echo "${domain}" | awk -F "." '{$1="";print $0}' | sed 's/^[[:space:]]*//' | sed 's/ /./g')
        acme_domain="*.${dnsTLSDomain}"
    fi

    if [[ "${USE_DNS_API}" == "y" ]]; then
        if [[ "${DNS_PROVIDER}" == "cloudflare" ]]; then
            if [[ -z "${CF_API_TOKEN}" ]]; then echoContent red "CF_API_TOKEN is required for Cloudflare DNS API"; exit 1; fi
            export CF_Token="${CF_API_TOKEN}"
            dns_api_params="--dns dns_cf"
        elif [[ "${DNS_PROVIDER}" == "aliyun" ]]; then
            if [[ -z "${ALI_KEY}" || -z "${ALI_SECRET}" ]]; then echoContent red "ALI_KEY and ALI_SECRET are required for Aliyun DNS API"; exit 1; fi
            export Ali_Key="${ALI_KEY}"
            export Ali_Secret="${ALI_SECRET}"
            dns_api_params="--dns dns_ali"
        else
            echoContent red "Unsupported DNS_PROVIDER: ${DNS_PROVIDER}"
            exit 1
        fi
        echoContent green " ---> Generating certificate using DNS API for ${acme_domain}..."
        "$HOME/.acme.sh/acme.sh" --issue -d "${acme_domain}" -d "${domain}" ${dns_api_params} -k ec-256 --server "${sslType}"
    else
        echoContent green " ---> Generating certificate using standalone server for ${domain}..."
        # Start Nginx temporarily for the challenge
        mkdir -p /var/www/html
        cat > ${nginxConfigPath}acme.conf <<EOF
server {
    listen 80;
    server_name ${domain};
    root /var/www/html;
    location /.well-known/acme-challenge/ {
        default_type "text/plain";
    }
}
EOF
        nginx
        "$HOME/.acme.sh/acme.sh" --issue -d "${domain}" --webroot /var/www/html -k ec-256 --server "${sslType}"
        nginx -s stop
        rm ${nginxConfigPath}acme.conf
    fi
    
    if [[ $? -ne 0 ]]; then
        echoContent red " ---> Certificate generation failed. Check log at /root/.acme.sh/acme.sh.log"
        exit 1
    fi
}

installTLS() {
    echoContent skyBlue "\n[Step 3/${totalProgress}] Applying for TLS certificate..."
    
    "$HOME/.acme.sh/acme.sh" --set-default-ca --server "${sslType}"
    
    acmeInstallSSL
    
    local install_domain="${domain}"
    if [[ "${USE_WILDCARD_CERT}" == "y" ]]; then
        install_domain="*.${dnsTLSDomain}"
    fi
    
    "$HOME/.acme.sh/acme.sh" --install-cert -d "${install_domain}" --ecc \
        --fullchain-path "/etc/v2ray-agent/tls/${domain}.crt" \
        --key-path "/etc/v2ray-agent/tls/${domain}.key"
    
    if [[ ! -s "/etc/v2ray-agent/tls/${domain}.crt" || ! -s "/etc/v2ray-agent/tls/${domain}.key" ]]; then
        echoContent red " ---> Failed to install certificate to /etc/v2ray-agent/tls/"
        exit 1
    fi
    
    echoContent green " ---> TLS certificate successfully installed."
}

initRandomPath() {
    customPath=$(head /dev/urandom | tr -dc 'a-z' | head -c 5)
}

randomPathFunction() {
    echoContent skyBlue "\n[Step 5/${totalProgress}] Setting up path..."
    if [[ -z "${CUSTOM_PATH}" ]]; then
        initRandomPath
        currentPath=${customPath}
    else
        currentPath=${CUSTOM_PATH}
    fi
    echoContent yellow "\n ---> Path set to: /${currentPath}"
}

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

# --- Core Logic Functions (Full Versions) ---

# The full initXrayConfig from the original script, adapted for env vars
initXrayConfig() {
    echoContent skyBlue "\n[Step 7/${totalProgress}] Initializing Xray configuration..."
    configPath=/etc/v2ray-agent/xray/conf/

    if [[ -z "${customUUID}" ]]; then
        uuid=$(${ctlPath} uuid)
    else
        uuid=${customUUID}
    fi
    if [[ -z "${customEmail}" ]]; then
        email="${uuid}"
    else
        email=${customEmail}
    fi
    
    currentClients='[{"id":"'${uuid}'","flow":"xtls-rprx-vision","email":"'${email}'"}]'
    trojanClients='[{"password":"'${uuid}'","email":"'${email}'"}]'
    vmessClients='[{"id":"'${uuid}'","email":"'${email}'","alterId": 0}]'

    # Static files
    cat <<EOF >${configPath}00_log.json
{"log": {"error": "/dev/stdout", "loglevel": "warning"}}
EOF
    cat <<EOF >${configPath}12_policy.json
{"policy": {"levels": {"0": {"handshake": 4, "connIdle": 300}}}}
EOF
    cat <<EOF >${configPath}11_dns.json
{"dns": {"servers": ["localhost"]}}
EOF
    cat <<EOF >${configPath}09_routing.json
{"routing": {"rules": [{"type": "field","domain": ["domain:gstatic.com","domain:googleapis.com","domain:googleapis.cn"],"outboundTag": "z_direct_outbound"}]}}
EOF
    cat <<EOF >${configPath}z_direct_outbound.json
{"outbounds":[{"protocol":"freedom","settings": {"domainStrategy":"UseIP"},"tag":"z_direct_outbound"}]}
EOF

    # Dynamic inbound files based on protocols
    local fallbacksList='{"dest":31300,"xver":1},{"alpn":"h2","dest":31302,"xver":1}'

    if echo "${selectCustomInstallType}" | grep -q ",4,"; then
        fallbacksList='{"dest":31296,"xver":1},{"alpn":"h2","dest":31302,"xver":1}'
        cat <<EOF >${configPath}04_trojan_TCP_inbounds.json
{"inbounds":[{"port":31296,"listen":"127.0.0.1","protocol":"trojan","tag":"trojanTCP","settings":{"clients":${trojanClients},"fallbacks":[{"dest":"31300","xver":1}]},"streamSettings":{"network":"tcp","security":"none","tcpSettings":{"acceptProxyProtocol":true}}}]}
EOF
    fi

    if echo "${selectCustomInstallType}" | grep -q ",1,"; then
        fallbacksList=${fallbacksList}',{"path":"/'${currentPath}'ws","dest":31297,"xver":1}'
        cat <<EOF >${configPath}03_VLESS_WS_inbounds.json
{"inbounds":[{"port":31297,"listen":"127.0.0.1","protocol":"vless","tag":"VLESSWS","settings":{"clients":${currentClients},"decryption":"none"},"streamSettings":{"network":"ws","security":"none","wsSettings":{"acceptProxyProtocol":true,"path":"/${currentPath}ws"}}}]}
EOF
    fi

    if echo "${selectCustomInstallType}" | grep -q ",12,"; then
        initXrayXHTTPort
        initRealityClientServersName
        initRealityKey
        cat <<EOF >${configPath}12_VLESS_XHTTP_inbounds.json
{"inbounds":[{"port":${xHTTPort},"listen":"0.0.0.0","protocol":"vless","tag":"VLESSRealityXHTTP","settings":{"clients":${currentClients},"decryption":"none"},"streamSettings":{"network":"xhttp","security":"reality","realitySettings":{"show":false,"dest":"${realityServerName}:443","xver":0,"serverNames":["${realityServerName}"],"privateKey":"${realityPrivateKey}","publicKey":"${realityPublicKey}","shortIds":["","6ba85179e30d4fc2"]},"xhttpSettings":{"host":"${realityServerName}","path":"/${currentPath}xHTTP"}}}]}
EOF
    fi
    
    if echo "${selectCustomInstallType}" | grep -q ",3,"; then
        fallbacksList=${fallbacksList}',{"path":"/'${currentPath}'vws","dest":31299,"xver":1}'
        cat <<EOF >${configPath}05_VMess_WS_inbounds.json
{"inbounds":[{"listen":"127.0.0.1","port":31299,"protocol":"vmess","tag":"VMessWS","settings":{"clients":${vmessClients}},"streamSettings":{"network":"ws","security":"none","wsSettings":{"acceptProxyProtocol":true,"path":"/${currentPath}vws"}}}]}
EOF
    fi

    if echo "${selectCustomInstallType}" | grep -q ",5,"; then
        cat <<EOF >${configPath}06_VLESS_gRPC_inbounds.json
{"inbounds":[{"port":31301,"listen":"127.0.0.1","protocol":"vless","tag":"VLESSGRPC","settings":{"clients":${currentClients},"decryption":"none"},"streamSettings":{"network":"grpc","grpcSettings":{"serviceName":"${currentPath}grpc"}}}]}
EOF
    fi

    if echo "${selectCustomInstallType}" | grep -q ",0,"; then
        cat <<EOF >${configPath}02_VLESS_TCP_inbounds.json
{"inbounds":[{"port":${port},"protocol":"vless","tag":"VLESSTCP","settings":{"clients":${currentClients},"decryption":"none","fallbacks":[${fallbacksList}]},"streamSettings":{"network":"tcp","security":"tls","tlsSettings":{"rejectUnknownSni":true,"certificates":[{"certificateFile":"/etc/v2ray-agent/tls/${domain}.crt","keyFile":"/etc/v2ray-agent/tls/${domain}.key"}]}}}]}
EOF
    fi

    if echo "${selectCustomInstallType}" | grep -q ",7,"; then
        initXrayRealityPort
        initRealityClientServersName
        initRealityKey
        cat <<EOF >${configPath}07_VLESS_vision_reality_inbounds.json
{"inbounds":[{"port":${realityPort},"protocol":"vless","tag":"VLESSReality","settings":{"clients":${currentClients},"decryption":"none"},"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"${realityServerName}:443","xver":0,"serverNames":["${realityServerName}"],"privateKey":"${realityPrivateKey}","publicKey":"${realityPublicKey}","shortIds":["","6ba85179e30d4fc2"]}}}]}
EOF
    fi

    echoContent green " ---> Xray configuration initialized."
}

# The full initSingBoxConfig from the original script, adapted for env vars
initSingBoxConfig() {
    echoContent skyBlue "\n[Step 7/${totalProgress}] Initializing Sing-box configuration..."
    configPath=/etc/v2ray-agent/sing-box/conf/config/
    singBoxConfigPath=${configPath}

    if [[ -z "${customUUID}" ]]; then
        uuid=$(${ctlPath} generate uuid)
    else
        uuid=${customUUID}
    fi
    if [[ -z "${customEmail}" ]]; then
        name="${uuid}"
    else
        name=${customEmail}
    fi
    
    # Static files
    cat <<EOF >${configPath}log.json
{"log": {"disabled": false, "level": "info", "output": "/dev/stdout", "timestamp": true}}
EOF
    cat <<EOF >${configPath}dns.json
{"dns": {"servers":[{"address":"local"}]}}
EOF

    # Protocol-specific clients
    vlessClients='[{"uuid":"'${uuid}'","flow":"xtls-rprx-vision","name":"'${name}'"}]'
    vmessClients='[{"uuid":"'${uuid}'","name":"'${name}'","alterId": 0}]'
    trojanClients='[{"password":"'${uuid}'","name":"'${name}'"}]'
    hysteria2Clients='[{"password":"'${uuid}'","name":"'${name}'"}]'
    tuicClients='[{"uuid":"'${uuid}'","password":"'${uuid}'","name":"'${name}'"}]'
    naiveClients='[{"username":"'${name}'","password":"'${uuid}'"}]'
    
    # Dynamic inbound files
    if echo "${selectCustomInstallType}" | grep -q ",0,"; then
        cat <<EOF >${configPath}02_VLESS_TCP_inbounds.json
{"inbounds":[{"type":"vless","listen":"::","listen_port":${singBoxVLESSVisionPort:-$port},"tag":"VLESSTCP","users":${vlessClients},"tls":{"enabled":true,"server_name":"${domain}","certificate_path":"/etc/v2ray-agent/tls/${domain}.crt","key_path":"/etc/v2ray-agent/tls/${domain}.key"}}]}
EOF
    fi
    if echo "${selectCustomInstallType}" | grep -q ",1,"; then
        cat <<EOF >${configPath}03_VLESS_WS_inbounds.json
{"inbounds":[{"type":"vless","listen":"::","listen_port":${singBoxVLESSWSPort:-$(shuf -i 10000-20000 -n 1)},"tag":"VLESSWS","users":${vlessClients},"tls":{"enabled":true,"server_name":"${domain}","certificate_path":"/etc/v2ray-agent/tls/${domain}.crt","key_path":"/etc/v2ray-agent/tls/${domain}.key"},"transport":{"type":"ws","path":"/${currentPath}ws"}}]}
EOF
    fi
    if echo "${selectCustomInstallType}" | grep -q ",3,"; then
        cat <<EOF >${configPath}05_VMess_WS_inbounds.json
{"inbounds":[{"type":"vmess","listen":"::","listen_port":${singBoxVMessWSPort:-$(shuf -i 20001-30000 -n 1)},"tag":"VMessWS","users":${vmessClients},"tls":{"enabled":true,"server_name":"${domain}","certificate_path":"/etc/v2ray-agent/tls/${domain}.crt","key_path":"/etc/v2ray-agent/tls/${domain}.key"},"transport":{"type":"ws","path":"/${currentPath}"}}]}
EOF
    fi
    if echo "${selectCustomInstallType}" | grep -q ",4,"; then
        cat <<EOF >${configPath}04_trojan_TCP_inbounds.json
{"inbounds":[{"type":"trojan","listen":"::","listen_port":${singBoxTrojanPort:-$(shuf -i 30001-40000 -n 1)},"users":${trojanClients},"tls":{"enabled":true,"server_name":"${domain}","certificate_path":"/etc/v2ray-agent/tls/${domain}.crt","key_path":"/etc/v2ray-agent/tls/${domain}.key"}}]}
EOF
    fi
    if echo "${selectCustomInstallType}" | grep -q ",6,"; then
        cat <<EOF >${configPath}06_hysteria2_inbounds.json
{"inbounds":[{"type":"hysteria2","listen":"::","listen_port":${hysteriaPort:-$(shuf -i 40001-50000 -n 1)},"users":${hysteria2Clients},"up_mbps":${hysteria2ClientUploadSpeed},"down_mbps":${hysteria2ClientDownloadSpeed},"tls":{"enabled":true,"server_name":"${domain}","alpn":["h3"],"certificate_path":"/etc/v2ray-agent/tls/${domain}.crt","key_path":"/etc/v2ray-agent/tls/${domain}.key"}}]}
EOF
    fi
    if echo "${selectCustomInstallType}" | grep -q ",7,"; then
        initRealityKey; initRealityClientServersName
        cat <<EOF >${configPath}07_VLESS_vision_reality_inbounds.json
{"inbounds":[{"type":"vless","listen":"::","listen_port":${singBoxVLESSRealityVisionPort:-$port},"tag":"VLESSReality","users":${vlessClients},"tls":{"enabled":true,"server_name":"${realityServerName}","reality":{"enabled":true,"handshake":{"server":"${realityServerName}","server_port":443},"private_key":"${realityPrivateKey}","short_id":["6ba85179e30d4fc2"]}}}]}
EOF
    fi
    if echo "${selectCustomInstallType}" | grep -q ",8,"; then
        initRealityKey; initRealityClientServersName
        cat <<EOF >${configPath}08_VLESS_vision_gRPC_inbounds.json
{"inbounds":[{"type":"vless","listen":"::","listen_port":${singBoxVLESSRealityGRPCPort:-$(shuf -i 50001-60000 -n 1)},"users":${vlessClients},"tag":"VLESSRealityGRPC","tls":{"enabled":true,"server_name":"${realityServerName}","reality":{"enabled":true,"handshake":{"server":"${realityServerName}","server_port":443},"private_key":"${realityPrivateKey}","short_id":["6ba85179e30d4fc2"]}},"transport":{"type":"grpc","service_name":"grpc"}}]}
EOF
    fi
    if echo "${selectCustomInstallType}" | grep -q ",9,"; then
        cat <<EOF >${configPath}09_tuic_inbounds.json
{"inbounds":[{"type":"tuic","listen":"::","tag":"singbox-tuic-in","listen_port":${tuicPort:-$(shuf -i 30001-40000 -n 1)},"users":${tuicClients},"congestion_control":"${tuicAlgorithm}","tls":{"enabled":true,"server_name":"${domain}","alpn":["h3"],"certificate_path":"/etc/v2ray-agent/tls/${domain}.crt","key_path":"/etc/v2ray-agent/tls/${domain}.key"}}]}
EOF
    fi
    if echo "${selectCustomInstallType}" | grep -q ",10,"; then
        cat <<EOF >${configPath}10_naive_inbounds.json
{"inbounds":[{"type":"naive","listen":"::","tag":"singbox-naive-in","listen_port":${singBoxNaivePort:-$(shuf -i 40001-50000 -n 1)},"users":${naiveClients},"tls":{"enabled":true,"server_name":"${domain}","certificate_path":"/etc/v2ray-agent/tls/${domain}.crt","key_path":"/etc/v2ray-agent/tls/${domain}.key"}}]}
EOF
    fi
    if echo "${selectCustomInstallType}" | grep -q ",11,"; then
        singBoxNginxConfig ${singBoxVMessHTTPUpgradePort:-$(shuf -i 50001-60000 -n 1)}
        cat <<EOF >${configPath}11_VMess_HTTPUpgrade_inbounds.json
{"inbounds":[{"type":"vmess","listen":"127.0.0.1","listen_port":31306,"tag":"VMessHTTPUpgrade","users":${vmessClients},"transport":{"type":"httpupgrade","path":"/${currentPath}"}}]}
EOF
    fi
    
    echoContent green " ---> Sing-box configuration initialized."
}


# --- Reality Helper Functions ---
initRealityKey() {
    echoContent skyBlue "\nGenerating Reality key..."
    if [[ "${CORE_TYPE}" == "2" ]]; then
        realityX25519Key=$(${ctlPath} generate reality-keypair)
        realityPrivateKey=$(echo "${realityX25519Key}" | head -1 | awk '{print $2}')
        realityPublicKey=$(echo "${realityX25519Key}" | tail -n 1 | awk '{print $2}')
    else
        realityX25519Key=$(${ctlPath} x25519)
        realityPrivateKey=$(echo "${realityX25519Key}" | head -1 | awk '{print $3}')
        realityPublicKey=$(echo "${realityX25519Key}" | tail -n 1 | awk '{print $3}')
    fi
    echoContent green "\n ---> privateKey: ${realityPrivateKey}"
    echoContent green "\n ---> publicKey:  ${realityPublicKey}"
}

initRealityClientServersName() {
    if [[ -z "${REALITY_SERVER_NAME}" ]]; then
        local realityDestDomainList="www.apple.com,www.microsoft.com,dl.google.com,www.google-analytics.com"
        realityServerName=$(echo "${realityDestDomainList}" | tr ',' '\n' | shuf -n 1)
        echoContent yellow " ---> Randomly selected Reality server name: ${realityServerName}"
    else
        realityServerName=${REALITY_SERVER_NAME}
        echoContent yellow " ---> Using provided Reality server name: ${realityServerName}"
    fi
}

initXrayRealityPort() {
    if [[ -z "${realityPort}" ]]; then
        realityPort=$(shuf -i 10000-20000 -n 1)
    fi
    echoContent yellow "\n ---> Reality Port: ${realityPort}"
}

initXrayXHTTPort() {
    if [[ -z "${xHTTPort}" ]]; then
        xHTTPort=$(shuf -i 20001-30000 -n 1)
    fi
    echoContent yellow "\n ---> XHTTP Port: ${xHTTPort}"
}

# --- MAIN EXECUTION LOGIC ---

echoContent skyBlue "=================================================="
echoContent skyBlue "  Starting v2ray-agent Docker Entrypoint (Full)"
echoContent skyBlue "=================================================="

# 1. Initialization
initVar
checkSystem
checkCPUVendor
mkdirTools

# 2. Validate Environment Variables
if [[ -z "${CORE_TYPE}" ]]; then
    echoContent red "CORE_TYPE is not set. Use '1' for Xray or '2' for Sing-box."
    exit 1
fi
if [[ -z "${INSTALL_PROTOCOLS}" ]]; then
    echoContent red "INSTALL_PROTOCOLS is not set. Provide a comma-separated list of protocol numbers."
    exit 1
fi

# 3. Setup Flow
installTools

is_reality_only=false
if [[ "${INSTALL_PROTOCOLS}" == "7" || "${INSTALL_PROTOCOLS}" == "8" || "${INSTALL_PROTOCOLS}" == "7,8" || "${INSTALL_PROTOCOLS}" == "8,7" ]]; then
    is_reality_only=true
fi

# Install TLS if any non-Reality protocol is selected
if [[ "${is_reality_only}" = false ]]; then
    initTLSNginxConfig
    installTLS
fi

# Generate random path if needed for ws/grpc/httpupgrade
if [[ "${selectCustomInstallType}" =~ ",1," || "${selectCustomInstallType}" =~ ",3," || "${selectCustomInstallType}" =~ ",5," || "${selectCustomInstallType}" =~ ",11," || "${selectCustomInstallType}" =~ ",12," ]]; then
    randomPathFunction
fi

# Setup camouflage site if Nginx is going to be used
if [[ "${CORE_TYPE}" == "1" && "${is_reality_only}" = false ]] || [[ "${selectCustomInstallType}" =~ ",11," ]]; then
    nginxBlog
fi

# 4. Install and Configure Core
if [[ "${CORE_TYPE}" == "1" ]]; then
    echoContent skyBlue "--- XRAY-CORE SETUP ---"
    installXray
    if [[ "${is_reality_only}" = false ]]; then
        updateRedirectNginxConf
    fi
    initXrayConfig
    
    if [[ "${is_reality_only}" = false ]]; then
       handleNginx start
    fi
    echoContent green "\n[Step 9/${totalProgress}] Starting Xray-core as main process..."
    exec /etc/v2ray-agent/xray/xray run -confdir /etc/v2ray-agent/xray/conf
    
elif [[ "${CORE_TYPE}" == "2" ]]; then
    echoContent skyBlue "--- SING-BOX SETUP ---"
    installSingBox
    initSingBoxConfig
    
    # Start Nginx if needed for HTTPUpgrade
    if [[ "${selectCustomInstallType}" =~ ",11," ]]; then
        handleNginx start
    fi
    
    # Merge sing-box configs
    /etc/v2ray-agent/sing-box/sing-box merge config.json -C /etc/v2ray-agent/sing-box/conf/config/ -D /etc/v2ray-agent/sing-box/conf/ >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echoContent red "Failed to merge sing-box configuration files."
        /etc/v2ray-agent/sing-box/sing-box check -C /etc/v2ray-agent/sing-box/conf/config/
        exit 1
    fi
    
    echoContent green "\n[Step 9/${totalProgress}] Starting sing-box as main process..."
    exec /etc/v2ray-agent/sing-box/sing-box run -c /etc/v2ray-agent/sing-box/conf/config.json
fi

echoContent red "Entrypoint finished without starting a core process. Exiting."
exit 1
