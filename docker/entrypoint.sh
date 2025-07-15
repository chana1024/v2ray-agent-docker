
#!/usr/bin/env bash

# --- Helper Functions ---
echo_info() {
    echo "[INFO] $1"
}

echo_error() {
    echo "[ERROR] $1"
    exit 1
}

# --- Variable Definitions ---
CORE_TYPE=${CORE_TYPE:-xray}
PROTOCOLS=${PROTOCOLS:-VLESS_vision_reality}
DOMAIN=${DOMAIN:?"DOMAIN environment variable is not set."}
UUID=${UUID:?"UUID environment variable is not set."}
CDN_ADDRESS=${CDN_ADDRESS:-$DOMAIN}

# --- Core Installation ---
install_core() {
    echo_info "Installing core: $CORE_TYPE"
    case "$CORE_TYPE" in
        xray)
            bash <(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install
            ;;
        sing-box)
            bash <(curl -fsSL https://sing-box.app/deb-install.sh) install
            ;;
        *)
            echo_error "Invalid CORE_TYPE: $CORE_TYPE"
            ;;
    esac
}

# --- Certificate Management ---
issue_cert() {
    echo_info "Issuing certificate for $DOMAIN..."
    /root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone -k ec-256
    /root/.acme.sh/acme.sh --installcert -d "$DOMAIN" --fullchainpath "/etc/v2ray-agent/tls/$DOMAIN.crt" --keypath "/etc/v2ray-agent/tls/$DOMAIN.key" --ecc
}

# --- Configuration Generation ---
generate_nginx_config() {
    echo_info "Generating Nginx config..."

    local locations=""

    # VLESS_ws_tls location
    if [[ "$PROTOCOLS" == *"VLESS_ws_tls"* ]]; then
        locations="$locations\n    location /vless {\n        proxy_pass http://127.0.0.1:10001;\n        proxy_http_version 1.1;\n        proxy_set_header Upgrade \$http_upgrade;\n        proxy_set_header Connection \"upgrade\";\n    }"
    fi

    # ... (add other protocol locations here)

    cat <<EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/v2ray-agent/tls/$DOMAIN.crt;
    ssl_certificate_key /etc/v2ray-agent/tls/$DOMAIN.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    $locations

    location /subscribe/$UUID {
        alias /etc/v2ray-agent/subscribe/default;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }
}
EOF
    echo_info "Nginx config generated."
}

generate_xray_config() {
    # ... (to be implemented)
}

generate_sing_box_config() {
    echo_info "Generating sing-box config for $PROTOCOLS..."

    local base_config='{
        "log": {"level": "info", "timestamp": true},
        "inbounds": [],
        "outbounds": [{"type": "direct", "tag": "direct"}]
    }'

    local inbounds="$(echo "$base_config" | jq .inbounds)"

    # VLESS_vision_reality Protocol
    if [[ "$PROTOCOLS" == *"VLESS_vision_reality"* ]]; then
        local reality_keys=$(/usr/local/bin/sing-box generate reality-keypair)
        local private_key=$(echo "$reality_keys" | jq -r .private_key)
        local public_key=$(echo "$reality_keys" | jq -r .public_key)

        local vless_reality_inbound=$(jq -n --arg uuid "$UUID" --arg private_key "$private_key" --arg domain "$DOMAIN" \
        '{
            "type": "vless",
            "tag": "vless-reality-in",
            "listen": "::",
            "listen_port": 10000,
            "users": [
                {
                    "uuid": \$uuid,
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": \$domain,
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "www.google.com",
                        "server_port": 443
                    },
                    "private_key": \$private_key
                }
            }
        }')
        inbounds=$(echo "$inbounds" | jq --argjson new_inbound "$vless_reality_inbound" '. + [\$new_inbound]')
    fi

    # VLESS_ws_tls Protocol
    if [[ "$PROTOCOLS" == *"VLESS_ws_tls"* ]]; then
        local vless_ws_inbound=$(jq -n --arg uuid "$UUID" \
        '{
            "type": "vless",
            "tag": "vless-ws-in",
            "listen": "::",
            "listen_port": 10001,
            "users": [
                {
                    "uuid": \$uuid
                }
            ],
            "transport": {
                "type": "ws",
                "path": "/vless"
            }
        }')
        inbounds=$(echo "$inbounds" | jq --argjson new_inbound "$vless_ws_inbound" '. + [\$new_inbound]')
    fi

    local final_config=$(echo "$base_config" | jq --argjson new_inbounds "$inbounds" '.inbounds = \$new_inbounds')

    echo "$final_config" > /etc/v2ray-agent/sing-box/config.json
    echo_info "sing-box config generated."
}

generate_config() {
    echo_info "Generating configuration for $CORE_TYPE with protocols: $PROTOCOLS"
    generate_nginx_config
    if [ "$CORE_TYPE" = "xray" ]; then
        generate_xray_config
    elif [ "$CORE_TYPE" = "sing-box" ]; then
        generate_sing_box_config
    fi
}

# --- Subscription Generation ---
generate_subscription_file() {
    echo_info "Generating subscription file..."
    local subscription_content=""

    # VLESS_ws_tls subscription
    if [[ "$PROTOCOLS" == *"VLESS_ws_tls"* ]]; then
        subscription_content="$subscription_content\nvless://$UUID@$CDN_ADDRESS:443?path=%2Fvless&security=tls&sni=$DOMAIN&type=ws#VLESS_ws_tls"
    fi

    # ... (add other protocol subscriptions here)

    echo -e "$subscription_content" > /etc/v2ray-agent/subscribe/default
    echo_info "Subscription file generated."
}

# --- Service Management ---
start_services() {
    echo_info "Starting services..."
    nginx -g 'daemon off;' &
    /usr/local/bin/$CORE_TYPE run -config /etc/v2ray-agent/$CORE_TYPE/config.json &
    wait
}

# --- Main Execution ---
main() {
    install_core

    if [ ! -f "/etc/v2ray-agent/tls/$DOMAIN.crt" ]; then
        issue_cert
    fi

    generate_config
    generate_subscription_file
    start_services
}

main
