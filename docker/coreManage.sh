
# 重启核心
reloadCore() {
    if [[ "${CORE_TYPE}" == "1" ]]; then
        handleXray stop
        handleXray start
    fi
    if [[ "${coreInstallType}" == "2" ]]; then
        handleSingBox stop
        handleSingBox start
    fi
}

# 操作xray
handleXray() {
    if [[ -z $(pgrep -f "xray/xray") ]] && [[ "$1" == "start" ]]; then
        systemctl start xray.service
    elif [[ -n $(pgrep -f "xray/xray") ]] && [[ "$1" == "stop" ]]; then
        systemctl stop xray.service
    fi

    sleep 0.8

    if [[ "$1" == "start" ]]; then
        if [[ -n $(pgrep -f "xray/xray") ]]; then
            echoContent green " ---> Xray启动成功"
        else
            echoContent red "Xray启动失败"
            echoContent red "请手动执行以下的命令后【/etc/v2ray-agent/xray/xray -confdir /etc/v2ray-agent/xray/conf】将错误日志进行反馈"
            exit 0
        fi
    elif [[ "$1" == "stop" ]]; then
        if [[ -z $(pgrep -f "xray/xray") ]]; then
            echoContent green " ---> Xray关闭成功"
        else
            echoContent red "xray关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep xray|awk '{print \$2}'|xargs kill -9】"
            exit 0
        fi
    fi
}

# 操作sing-box
handleSingBox() {
    if [[ -z $(pgrep -f "sing-box") ]] && [[ "$1" == "start" ]]; then
        singBoxMergeConfig
        systemctl start sing-box.service
    elif [[ -n $(pgrep -f "sing-box") ]] && [[ "$1" == "stop" ]]; then
        systemctl stop sing-box.service
    fi
    sleep 1

    if [[ "$1" == "start" ]]; then
        if [[ -n $(pgrep -f "sing-box") ]]; then
            echoContent green " ---> sing-box启动成功"
        else
            echoContent red "sing-box启动失败"
            echoContent yellow "请手动执行【 /etc/v2ray-agent/sing-box/sing-box merge config.json -C /etc/v2ray-agent/sing-box/conf/config/ -D /etc/v2ray-agent/sing-box/conf/ 】，查看错误日志"
            echo
            echoContent yellow "如上面命令没有错误，请手动执行【 /etc/v2ray-agent/sing-box/sing-box run -c /etc/v2ray-agent/sing-box/conf/config.json 】，查看错误日志"
            exit 0
        fi
    elif [[ "$1" == "stop" ]]; then
        if [[ -z $(pgrep -f "sing-box") ]]; then
            echoContent green " ---> sing-box关闭成功"
        else
            echoContent red " ---> sing-box关闭失败"
            echoContent red "请手动执行【ps -ef|grep -v grep|grep sing-box|awk '{print \$2}'|xargs kill -9】"
            exit 0
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

    installXrayService
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
    installSingBoxService
}


# 合并config
singBoxMergeConfig() {
    rm /etc/v2ray-agent/sing-box/conf/config.json >/dev/null 2>&1
    /etc/v2ray-agent/sing-box/sing-box merge config.json -C /etc/v2ray-agent/sing-box/conf/config/ -D /etc/v2ray-agent/sing-box/conf/ >/dev/null 2>&1
}
# sing-box开机自启
installSingBoxService() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置sing-box开机自启"
    execStart='/etc/v2ray-agent/sing-box/sing-box run -c /etc/v2ray-agent/sing-box/conf/config.json'

        rm -rf /etc/systemd/system/sing-box.service
        touch /etc/systemd/system/sing-box.service
        cat <<EOF >/etc/systemd/system/sing-box.service
[Unit]
Description=Sing-Box Service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=${execStart}
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10
LimitNPROC=infinity
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    bootStartup "sing-box.service"
    echoContent green " ---> 配置sing-box开机启动完毕"
}

# Xray开机自启
installXrayService() {
    echoContent skyBlue "\n进度  $1/${totalProgress} : 配置Xray开机自启"
    execStart='/etc/v2ray-agent/xray/xray run -confdir /etc/v2ray-agent/xray/conf'
        rm -rf /etc/systemd/system/xray.service
        touch /etc/systemd/system/xray.service
        cat <<EOF >/etc/systemd/system/xray.service
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target
[Service]
User=root
ExecStart=${execStart}
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=infinity
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
        bootStartup "xray.service"
        echoContent green " ---> 配置Xray开机自启成功"
}
# The full initXrayConfig from the original script, adapted for env vars
initXrayConfig() {
    echoContent skyBlue "\n[Step 7/${totalProgress}] Initializing Xray configuration..."
    configPath=/etc/v2ray-agent/xray/conf/

    if [[ -z "${UUID}" ]]; then
        uuid=$(${ctlPath} uuid)
    else
        uuid=${UUID}
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
{"routing": {"rules": [{"type": "field","DOMAIN": ["DOMAIN:gstatic.com","DOMAIN:googleapis.com","DOMAIN:googleapis.cn"],"outboundTag": "z_direct_outbound"}]}}
EOF
    cat <<EOF >${configPath}z_direct_outbound.json
{"outbounds":[{"protocol":"freedom","settings": {"DOMAINStrategy":"UseIP"},"tag":"z_direct_outbound"}]}
EOF

    # Dynamic inbound files based on protocols
    local fallbacksList='{"dest":31300,"xver":1},{"alpn":"h2","dest":31302,"xver":1}'

    if echo "${INSTALL_PROTOCOLS}" | grep -q ",4,"; then
        fallbacksList='{"dest":31296,"xver":1},{"alpn":"h2","dest":31302,"xver":1}'
        cat <<EOF >${configPath}04_trojan_TCP_inbounds.json
{"inbounds":[{"port":31296,"listen":"127.0.0.1","protocol":"trojan","tag":"trojanTCP","settings":{"clients":${trojanClients},"fallbacks":[{"dest":"31300","xver":1}]},"streamSettings":{"network":"tcp","security":"none","tcpSettings":{"acceptProxyProtocol":true}}}]}
EOF
    fi

    if echo "${INSTALL_PROTOCOLS}" | grep -q ",1,"; then
        fallbacksList=${fallbacksList}',{"path":"/'${currentPath}'ws","dest":31297,"xver":1}'
        cat <<EOF >${configPath}03_VLESS_WS_inbounds.json
{"inbounds":[{"port":31297,"listen":"127.0.0.1","protocol":"vless","tag":"VLESSWS","settings":{"clients":${currentClients},"decryption":"none"},"streamSettings":{"network":"ws","security":"none","wsSettings":{"acceptProxyProtocol":true,"path":"/${currentPath}ws"}}}]}
EOF
    fi

    if echo "${INSTALL_PROTOCOLS}" | grep -q ",12,"; then
        initXrayXHTTPort
        initRealityClientServersName
        initRealityKey
        cat <<EOF >${configPath}12_VLESS_XHTTP_inbounds.json
{"inbounds":[{"port":${xHTTPort},"listen":"0.0.0.0","protocol":"vless","tag":"VLESSRealityXHTTP","settings":{"clients":${currentClients},"decryption":"none"},"streamSettings":{"network":"xhttp","security":"reality","realitySettings":{"show":false,"dest":"${realityServerName}:443","xver":0,"serverNames":["${realityServerName}"],"privateKey":"${realityPrivateKey}","publicKey":"${realityPublicKey}","shortIds":["","6ba85179e30d4fc2"]},"xhttpSettings":{"host":"${realityServerName}","path":"/${currentPath}xHTTP"}}}]}
EOF
    fi
    
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",3,"; then
        fallbacksList=${fallbacksList}',{"path":"/'${currentPath}'vws","dest":31299,"xver":1}'
        cat <<EOF >${configPath}05_VMess_WS_inbounds.json
{"inbounds":[{"listen":"127.0.0.1","port":31299,"protocol":"vmess","tag":"VMessWS","settings":{"clients":${vmessClients}},"streamSettings":{"network":"ws","security":"none","wsSettings":{"acceptProxyProtocol":true,"path":"/${currentPath}vws"}}}]}
EOF
    fi

    if echo "${INSTALL_PROTOCOLS}" | grep -q ",5,"; then
        cat <<EOF >${configPath}06_VLESS_gRPC_inbounds.json
{"inbounds":[{"port":31301,"listen":"127.0.0.1","protocol":"vless","tag":"VLESSGRPC","settings":{"clients":${currentClients},"decryption":"none"},"streamSettings":{"network":"grpc","grpcSettings":{"serviceName":"${currentPath}grpc"}}}]}
EOF
    fi

    if echo "${INSTALL_PROTOCOLS}" | grep -q ",0,"; then
        cat <<EOF >${configPath}02_VLESS_TCP_inbounds.json
{"inbounds":[{"port":${port},"protocol":"vless","tag":"VLESSTCP","settings":{"clients":${currentClients},"decryption":"none","fallbacks":[${fallbacksList}]},"streamSettings":{"network":"tcp","security":"tls","tlsSettings":{"rejectUnknownSni":true,"certificates":[{"certificateFile":"/etc/v2ray-agent/tls/${DOMAIN}.crt","keyFile":"/etc/v2ray-agent/tls/${DOMAIN}.key"}]}}}]}
EOF
    fi

    if echo "${INSTALL_PROTOCOLS}" | grep -q ",7,"; then
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

    if [[ -z "${UUID}" ]]; then
        uuid=$(${ctlPath} generate uuid)
    else
        uuid=${UUID}
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
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",0,"; then
        cat <<EOF >${configPath}02_VLESS_TCP_inbounds.json
{"inbounds":[{"type":"vless","listen":"::","listen_port":${singBoxVLESSVisionPort:-$port},"tag":"VLESSTCP","users":${vlessClients},"tls":{"enabled":true,"server_name":"${DOMAIN}","certificate_path":"/etc/v2ray-agent/tls/${DOMAIN}.crt","key_path":"/etc/v2ray-agent/tls/${DOMAIN}.key"}}]}
EOF
    fi
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",1,"; then
        cat <<EOF >${configPath}03_VLESS_WS_inbounds.json
{"inbounds":[{"type":"vless","listen":"::","listen_port":${singBoxVLESSWSPort:-$(shuf -i 10000-20000 -n 1)},"tag":"VLESSWS","users":${vlessClients},"tls":{"enabled":true,"server_name":"${DOMAIN}","certificate_path":"/etc/v2ray-agent/tls/${DOMAIN}.crt","key_path":"/etc/v2ray-agent/tls/${DOMAIN}.key"},"transport":{"type":"ws","path":"/${currentPath}ws"}}]}
EOF
    fi
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",3,"; then
        cat <<EOF >${configPath}05_VMess_WS_inbounds.json
{"inbounds":[{"type":"vmess","listen":"::","listen_port":${singBoxVMessWSPort:-$(shuf -i 20001-30000 -n 1)},"tag":"VMessWS","users":${vmessClients},"tls":{"enabled":true,"server_name":"${DOMAIN}","certificate_path":"/etc/v2ray-agent/tls/${DOMAIN}.crt","key_path":"/etc/v2ray-agent/tls/${DOMAIN}.key"},"transport":{"type":"ws","path":"/${currentPath}"}}]}
EOF
    fi
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",4,"; then
        cat <<EOF >${configPath}04_trojan_TCP_inbounds.json
{"inbounds":[{"type":"trojan","listen":"::","listen_port":${singBoxTrojanPort:-$(shuf -i 30001-40000 -n 1)},"users":${trojanClients},"tls":{"enabled":true,"server_name":"${DOMAIN}","certificate_path":"/etc/v2ray-agent/tls/${DOMAIN}.crt","key_path":"/etc/v2ray-agent/tls/${DOMAIN}.key"}}]}
EOF
    fi
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",6,"; then
        cat <<EOF >${configPath}06_hysteria2_inbounds.json
{"inbounds":[{"type":"hysteria2","listen":"::","listen_port":${hysteriaPort:-$(shuf -i 40001-50000 -n 1)},"users":${hysteria2Clients},"up_mbps":${hysteria2ClientUploadSpeed},"down_mbps":${hysteria2ClientDownloadSpeed},"tls":{"enabled":true,"server_name":"${DOMAIN}","alpn":["h3"],"certificate_path":"/etc/v2ray-agent/tls/${DOMAIN}.crt","key_path":"/etc/v2ray-agent/tls/${DOMAIN}.key"}}]}
EOF
    fi
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",7,"; then
        initRealityKey; initRealityClientServersName
        cat <<EOF >${configPath}07_VLESS_vision_reality_inbounds.json
{"inbounds":[{"type":"vless","listen":"::","listen_port":${singBoxVLESSRealityVisionPort:-$port},"tag":"VLESSReality","users":${vlessClients},"tls":{"enabled":true,"server_name":"${realityServerName}","reality":{"enabled":true,"handshake":{"server":"${realityServerName}","server_port":443},"private_key":"${realityPrivateKey}","short_id":["6ba85179e30d4fc2"]}}}]}
EOF
    fi
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",8,"; then
        initRealityKey; initRealityClientServersName
        cat <<EOF >${configPath}08_VLESS_vision_gRPC_inbounds.json
{"inbounds":[{"type":"vless","listen":"::","listen_port":${singBoxVLESSRealityGRPCPort:-$(shuf -i 50001-60000 -n 1)},"users":${vlessClients},"tag":"VLESSRealityGRPC","tls":{"enabled":true,"server_name":"${realityServerName}","reality":{"enabled":true,"handshake":{"server":"${realityServerName}","server_port":443},"private_key":"${realityPrivateKey}","short_id":["6ba85179e30d4fc2"]}},"transport":{"type":"grpc","service_name":"grpc"}}]}
EOF
    fi
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",9,"; then
        cat <<EOF >${configPath}09_tuic_inbounds.json
{"inbounds":[{"type":"tuic","listen":"::","tag":"singbox-tuic-in","listen_port":${tuicPort:-$(shuf -i 30001-40000 -n 1)},"users":${tuicClients},"congestion_control":"${TUIC_ALGORITHM}","tls":{"enabled":true,"server_name":"${DOMAIN}","alpn":["h3"],"certificate_path":"/etc/v2ray-agent/tls/${DOMAIN}.crt","key_path":"/etc/v2ray-agent/tls/${DOMAIN}.key"}}]}
EOF
    fi
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",10,"; then
        cat <<EOF >${configPath}10_naive_inbounds.json
{"inbounds":[{"type":"naive","listen":"::","tag":"singbox-naive-in","listen_port":${singBoxNaivePort:-$(shuf -i 40001-50000 -n 1)},"users":${naiveClients},"tls":{"enabled":true,"server_name":"${DOMAIN}","certificate_path":"/etc/v2ray-agent/tls/${DOMAIN}.crt","key_path":"/etc/v2ray-agent/tls/${DOMAIN}.key"}}]}
EOF
    fi
    if echo "${INSTALL_PROTOCOLS}" | grep -q ",11,"; then
        singBoxNginxConfig ${singBoxVMessHTTPUpgradePort:-$(shuf -i 50001-60000 -n 1)}
        cat <<EOF >${configPath}11_VMess_HTTPUpgrade_inbounds.json
{"inbounds":[{"type":"vmess","listen":"127.0.0.1","listen_port":31306,"tag":"VMessHTTPUpgrade","users":${vmessClients},"transport":{"type":"httpupgrade","path":"/${currentPath}"}}]}
EOF
    fi
    
    echoContent green " ---> Sing-box configuration initialized."
}
