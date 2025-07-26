#!/bin/bash

export DOMAIN="san.fkgfw.store"
export CF_API_TOKEN="oDCYW72DWjFd-2lYLK0pVZloO499A0zK-2yifmbA"
export SSL_EMAIL="linzhinan1024@gmail.com"
#================================================
# 颜色定义
#================================================
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
skyBlue='\033[0;36m'
plain='\033[0m'

# 封装一个统一的打印函数
echoContent() {
    CURRENT_TIME=$(date "+%F %H:%M:%S")
    case $1 in
    "red")
        echo -e "${CURRENT_TIME} ${red}[ERROR]${plain} $2"
        ;;
    "green")
        echo -e "${CURRENT_TIME} ${green}[INFO]${plain}  $2"
        ;;
    "yellow")
        echo -e "${CURRENT_TIME} ${yellow}[WARN]${plain}  $2"
        ;;
    *)
        echo -e "${CURRENT_TIME} [INFO]  $2"
        ;;
    esac
}

# 读取tls证书详情
readAcmeTLS() {
    local readAcmeDomain=
    if [[ -n "${DOMAIN}" ]]; then
        readAcmeDomain="${DOMAIN}"
    fi

    dnsTLSDomain=$(echo "${readAcmeDomain}" | awk -F "." '{$1="";print $0}' | sed 's/^[[:space:]]*//' | sed 's/ /./g')
    dnsAPIDomain="*.${dnsTLSDomain}"
    echo Content skyBlue " ---> 读取域名: ${dnsTLSDomain}"
    echo Content skyBlue " ---> 读取域名: ${dnsAPIDomain}"
    if [[ -d "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.key" && -f "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.cer" ]]; then
        installedDNSAPIStatus=true
    fi
}
# 更新证书
renewalTLS() {
   readAcmeTLS
    local DOMAIN=${DOMAIN}
    sslRenewalDays=90
    if [[ -d "$HOME/.acme.sh/${dnsAPIDomain}_ecc" && -f "$HOME/.acme.sh/${dnsAPIDomain}_ecc/${dnsAPIDomain}.key" && -f "$HOME/.acme.sh/${dnsAPIDomain}_ecc/${dnsAPIDomain}.cer" ]] || [[ "${installedDNSAPIStatus}" == "true" ]]; then
        modifyTime=

        if [[ "${installedDNSAPIStatus}" == "true" ]]; then
            modifyTime=$(stat --format=%z "$HOME/.acme.sh/*.${dnsTLSDomain}_ecc/*.${dnsTLSDomain}.cer")
        else
            modifyTime=$(stat --format=%z "$HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.cer")
        fi

        modifyTime=$(date +%s -d "${modifyTime}")
        currentTime=$(date +%s)
        ((stampDiff = currentTime - modifyTime))
        ((days = stampDiff / 86400))
        ((remainingDays = sslRenewalDays - days))

        tlsStatus=${remainingDays}
        if [[ ${remainingDays} -le 0 ]]; then
            tlsStatus="已过期"
        fi

        echoContent skyBlue " ---> 证书检查日期:$(date "+%F %H:%M:%S")"
        echoContent skyBlue " ---> 证书生成日期:$(date -d @"${modifyTime}" +"%F %H:%M:%S")"
        echoContent skyBlue " ---> 证书生成天数:${days}"
        echoContent skyBlue " ---> 证书剩余天数:"${tlsStatus}
        echoContent skyBlue " ---> 证书过期前最后一天自动更新，如更新失败请手动更新"

        if [[ ${remainingDays} -le 1 ]]; then
            echoContent yellow " ---> 重新生成证书"
            handleNginx stop

            if [[ "${coreInstallType}" == "1" ]]; then
                handleXray stop
            elif [[ "${coreInstallType}" == "2" ]]; then
                handleV2Ray stop
            fi

            sudo "$HOME/.acme.sh/acme.sh" --cron --home "$HOME/.acme.sh"
            sudo "$HOME/.acme.sh/acme.sh" --installcert -d "${DOMAIN}" --fullchainpath /etc/v2ray-agent/tls/"${DOMAIN}.crt" --keypath /etc/v2ray-agent/tls/"${DOMAIN}.key" --ecc
            reloadCore
            handleNginx start
        else
            echoContent green " ---> 证书有效"
        fi
    else
        echoContent red " ---> 未安装"
    fi
}
# 查看TLS证书的状态
checkTLStatus() {

    if [[ -d "$HOME/.acme.sh/${DOMAIN}_ecc" ]] && [[ -f "$HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key" ]] && [[ -f "$HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.cer" ]]; then
        modifyTime=$(stat "$HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.cer" | sed -n '7,6p' | awk '{print $2" "$3" "$4" "$5}')

        modifyTime=$(date +%s -d "${modifyTime}")
        currentTime=$(date +%s)
        ((stampDiff = currentTime - modifyTime))
        ((days = stampDiff / 86400))
        ((remainingDays = sslRenewalDays - days))

        tlsStatus=${remainingDays}
        if [[ ${remainingDays} -le 0 ]]; then
            tlsStatus="已过期"
        fi

        echoContent skyBlue " ---> 证书生成日期:$(date -d "@${modifyTime}" +"%F %H:%M:%S")"
        echoContent skyBlue " ---> 证书生成天数:${days}"
        echoContent skyBlue " ---> 证书剩余天数:${tlsStatus}"
    fi
}
#================================================
# 主执行函数
#================================================
installTLS() {
    readAcmeTLS
    # --- 1. 从环境变量获取并验证配置 ---
    echoContent green "脚本开始执行：检查环境变量..."

    if [[ -z "${DOMAIN}" || -z "${CF_API_TOKEN}" || -z "${SSL_EMAIL}" ]]; then
        echoContent red "环境变量缺失: 请确保 DOMAIN, CF_API_TOKEN, SSL_EMAIL 都已设置。"
        exit 1
    fi

    local certPath="/etc/v2ray-agent/tls/${DOMAIN}.crt"
    local keyPath="/etc/v2ray-agent/tls/${DOMAIN}.key"
    local acmeSHPath="$HOME/.acme.sh/acme.sh"
    local acmeLogPath="/etc/v2ray-agent/tls/acme.log"
    local cronLogPath="/etc/v2ray-agent/crontab_tls.log"
    
    # 确保 acme.sh 存在
    if [[ ! -f "${acmeSHPath}" ]]; then
        echoContent red "acme.sh 未找到: ${acmeSHPath}"
        exit 1
    fi
    
    # --- 2. 检查证书存在性，决定执行“续订”还是“首次签发” ---
    if [[ -s "${certPath}" && -s "${keyPath}" ]]; then
        # **续订逻辑 (根据您提供的 renewalTLS 函数)**
        renewalTLS 
    else
        # **首次签发逻辑**
        echoContent green "未找到证书，开始执行首次证书签发流程..."
        
        sudo mkdir -p /etc/v2ray-agent/tls
        
        # 注册 acme.sh 账户 (根据您的要求使用 echo 方式)
        echoContent green "注册 acme.sh 账户: ${SSL_EMAIL}"
        echo "ACCOUNT_EMAIL='${SSL_EMAIL}'" | sudo tee "$HOME/.acme.sh/account.conf" > /dev/null
        
        # 签发证书
        echoContent green "使用 Cloudflare DNS API 申请证书..."
        sudo CF_Token="${CF_API_TOKEN}" "${acmeSHPath}" --issue \
            -d "${dnsAPIDomain}" -d "${dnsTLSDomain}" \
            --dns dns_cf -k ec-256 --server "letsencrypt" >> "${acmeLogPath}" 2>&1

        if [[ ! -f "$HOME/.acme.sh/${dnsAPIDomain}_ecc/${dnsAPIDomain}.cer" ]]; then
            echoContent red "证书申请失败! 请检查日志: ${acmeLogPath}"
            exit 1
        fi
        
        echoContent green "证书申请成功, 正在安装..."
        sudo "${acmeSHPath}" --install-cert -d "${dnsAPIDomain}" --ecc \
            --fullchain-file "${certPath}" \
            --key-file "${keyPath}" >> "${acmeLogPath}" 2>&1
            
        if [[ -s "${certPath}" && -s "${keyPath}" ]]; then
            echoContent green "TLS 证书已成功安装!"
        else
            echoContent red "证书安装失败! 请检查日志: ${acmeLogPath}"
            exit 1
        fi
    fi
}

#================================================
# 定时任务安装 (根据您提供的 installCronTLS 函数)
#================================================
installCron() {
    echoContent green "正在设置 crontab 定时续订任务..."
    
    local cron_job="30 1 * * * /usr/bin/env bash $0 >> ${cronLogPath} 2>&1"
    
    # 使用临时文件来安全地修改 crontab
    crontab -l > /tmp/my_cron_backup 2>/dev/null
    
    # 移除旧的、由本脚本创建的任务，防止重复
    sed -i "\|$0|d" /tmp/my_cron_backup
    
    # 添加新的任务
    echo "$cron_job" >> /tmp/my_cron_backup
    
    # 安装新的 crontab
    crontab /tmp/my_cron_backup
    rm /tmp/my_cron_backup
    
    echoContent green "定时任务设置成功，将于每日 01:30 AM 自动执行续订检查。"
}


# ================================================
# 脚本入口
# ================================================
installTLS
