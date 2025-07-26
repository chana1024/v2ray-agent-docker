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
# 获取当前脚本所在的目录的绝对路径
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "${SCRIPT_DIR}/tls.sh"
source "${SCRIPT_DIR}/nginxManage.sh"
source "${SCRIPT_DIR}/coreManage.sh"

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

    if [[ ! -d "$HOME/.acme.sh" ]] || [[ -d "$HOME/.acme.sh" && -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
        echoContent green " ---> 安装acme.sh"
        curl -s https://get.acme.sh | sh >/etc/v2ray-agent/tls/acme.log 2>&1

        if [[ ! -d "$HOME/.acme.sh" ]] || [[ -z $(find "$HOME/.acme.sh/acme.sh") ]]; then
            echoContent red "  acme安装失败--->"
            tail -n 100 /etc/v2ray-agent/tls/acme.log
            echoContent yellow "错误排查:"
            echoContent red "  1.获取Github文件失败，请等待Github恢复后尝试，恢复进度可查看 [https://www.githubstatus.com/]"
            echoContent red "  2.acme.sh脚本出现bug，可查看[https://github.com/acmesh-official/acme.sh] issues"
            echoContent red "  3.如纯IPv6机器，请设置NAT64,可执行下方命令，如果添加下方命令还是不可用，请尝试更换其他NAT64"
            echoContent skyBlue "  sed -i \"1i\\\nameserver 2a00:1098:2b::1\\\nnameserver 2a00:1098:2c::1\\\nnameserver 2a01:4f8:c2c:123f::1\\\nnameserver 2a01:4f9:c010:3f02::1\" /etc/resolv.conf"
            exit 0
        fi
    fi
}




# Section: Configuration (TLS, Nginx, Core Logic)
# -------------------------------------------------------------
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
installTLS

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

startCore() {
    # Start supervisord in the background
    supervisord -c /etc/supervisor/supervisord.conf
    
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
        echoContent green "\n[Step 9/${totalProgress}] Starting Xray-core..."
        handleXray start
    elif [[ "${CORE_TYPE}" == "2" ]]; then
        echoContent skyBlue "--- SING-BOX SETUP ---"
        installSingBox
        initSingBoxConfig
        
        # Start Nginx if needed for HTTPUpgrade
        if [[ "${selectCustomInstallType}" =~ ",11," ]]; then
            handleNginx start
        fi
        
        # Merge sing-box configs
        fi
        
        # Merge sing-box configs
        /etc/v2ray-agent/sing-box/sing-box merge config.json -C /etc/v2ray-agent/sing-box/conf/config/ -D /etc/v2ray-agent/sing-box/conf/ >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echoContent red "Failed to merge sing-box configuration files."
            /etc/v2ray-agent/sing-box/sing-box check -C /etc/v2ray-agent/sing-box/conf/config/
            exit 1
        fi
        
        echoContent green "\n[Step 9/${totalProgress}] Starting sing-box as main process..."
        handleSingBox start
    fi
}
startCore
echoContent red "Entrypoint finished without starting a core process. Exiting."
exit 1
