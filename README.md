# SoftEther Gateway

一键部署SoftEther VPN Server，与3x-ui共存，端口5555，适用于智能分流网关架构。

## 架构

```
Windows (Clash分流) ──SOCKS5──▶ Oracle Cloud ──▶ 互联网
                                  ├─ 3x-ui (443/1080)
                                  └─ SoftEther Server (5555)
```

## 一键部署

```bash
# 1. 克隆仓库
git clone https://github.com/2061969365/softether-gateway.git
cd softether-gateway

# 2. 配置密码
cp .env.example .env
nano .env  # 修改为你自己的密码

# 3. 启动！
docker compose up -d

# 4. 查看初始化日志
docker logs -f softether
```

## 端口规划

| 服务 | 端口 | 说明 |
|------|------|------|
| 3x-ui 面板 | 2053 | 已有 |
| 3x-ui VLESS/TLS | 443 | 已有（独占） |
| 3x-ui SOCKS5 | 1080 | 已有（给Clash） |
| **SoftEther VPN** | **5555** | 本方案提供 |

## Oracle云安全组

只需放行：`TCP 5555`（必需）

如需L2TP/OpenVPN额外放行：`UDP 1194/500/4500/1701`

## Windows客户端连接

1. 下载 [SoftEther VPN Client](https://www.softether.org/5-download/history)
2. 新建连接 → 主机：`<Oracle云IP>`，端口：`5555`，Hub：`DEFAULT`
3. 输入用户名密码连接

## Docker镜像

GitHub Actions自动构建，镜像发布在：

```
ghcr.io/2061969365/softether-gateway:latest
```

基于 [siomiz/softethervpn](https://github.com/siomiz/SoftEtherVPN) 镜像。

## 技术细节

- **网络模式**：host（最佳性能，直接使用宿主机网络栈）
- **SecureNAT DHCP**：不推默认网关（`GW:0.0.0.0`），防止客户端路由劫持
- **监听端口**：从默认443改到5555，与3x-ui的443不冲突
- **持久化**：`./data/` 目录挂载，配置自动保存

## License

MIT
