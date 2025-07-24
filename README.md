
# v2ray-agent-docker

v2ray-agent 的 Docker 化版本，支持一键部署多种代理协议。

## 特性

- 🐳 Docker 容器化部署，简化安装和管理
- 🔧 支持多种代理协议 (VLESS, VMess, Trojan)
- 🔒 自动 TLS 证书管理 (Let's Encrypt)
- 📊 内置订阅服务和配置生成
- 🌐 支持 CDN 和 Cloudflare 集成
- 🔄 支持最新的 Reality 协议
- 🛠️ 提供便捷的管理脚本

## 快速开始

### 1. 安装 Docker

Ubuntu/Debian:
```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

### 2. 克隆项目

```bash
git clone https://github.com/chana1024/v2ray-agent-docker.git
cd v2ray-agent-docker/docker
```

### 3. 配置环境变量

```bash
cp .env.example .env
nano .env  # 编辑配置文件
```

必需配置项：
- `DOMAIN`: 你的域名
- `UUID`: 用户UUID (可用 `uuidgen` 生成)

### 4. 使用管理脚本

```bash
# 构建镜像并启动服务
sudo ./manage.sh build
sudo ./manage.sh start

# 查看服务状态
sudo ./manage.sh status

# 查看日志
sudo ./manage.sh logs
```

## 管理脚本命令

```bash
./manage.sh build     # 构建Docker镜像
./manage.sh start     # 启动服务
./manage.sh stop      # 停止服务
./manage.sh restart   # 重启服务
./manage.sh status    # 查看服务状态
./manage.sh logs      # 查看服务日志
./manage.sh shell     # 进入容器
./manage.sh config    # 显示当前配置
./manage.sh uuid      # 生成UUID
./manage.sh help      # 显示帮助信息
```

## 配置说明

主要配置项：

- `DOMAIN`: 你的域名 (必需)
- `UUID`: 用户 UUID (必需)
- `CORE_TYPE`: 核心类型 (xray/sing-box，默认: sing-box)
- `PROTOCOLS`: 启用的协议列表 (逗号分隔)
- `CF_TOKEN`: Cloudflare API Token (用于DNS验证，可选)
- `SSL_TYPE`: SSL证书提供商 (默认: letsencrypt)

## 支持的协议

- **VLESS + Vision + Reality**: 最新的抗审查协议
- **VLESS + WebSocket + TLS**: 适合CDN中转
- **VMess + WebSocket + TLS**: 经典协议
- **Trojan + WebSocket + TLS**: 伪装性好

## 端口说明

- `80`: HTTP (自动重定向到HTTPS)
- `443`: HTTPS/TLS
- `10000`: VLESS Reality 直连端口
- `10001`: VLESS WebSocket 端口

## 数据持久化

所有配置和证书数据存储在 `./v2ray-data` 目录中：
- TLS证书文件
- 代理配置文件
- 订阅文件
- 日志文件

## 订阅链接

订阅链接地址：
```
https://your_domain.com/subscribe/your_uuid
```

## 目录结构

```
docker/
├── Dockerfile          # Docker 镜像构建文件
├── docker-compose.yml  # Docker Compose 配置
├── entrypoint.sh       # 容器启动脚本
├── manage.sh           # 管理脚本
├── .env.example        # 环境变量示例
├── README.md           # 使用说明
└── v2ray-data/         # 数据持久化目录
```

## 故障排除

### 查看详细日志
```bash
sudo ./manage.sh logs
```

### 重新生成证书
```bash
sudo docker compose exec v2ray-agent rm -rf /etc/v2ray-agent/tls/*
sudo ./manage.sh restart
```

### 检查配置文件
```bash
sudo docker compose exec v2ray-agent cat /etc/v2ray-agent/sing-box/config.json
```

## 安全建议

1. 使用强密码和复杂的UUID
2. 定期更新Docker镜像
3. 配置防火墙规则
4. 使用Cloudflare CDN保护真实IP
5. 定期备份配置数据

## 更新

```bash
git pull
sudo ./manage.sh build
sudo ./manage.sh restart
```

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 支持

如果这个项目对你有帮助，请给个 ⭐️ Star！
