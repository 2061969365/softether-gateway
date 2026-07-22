#!/bin/bash
# post-init.sh — 后台等待 vpnserver 就绪后设置 DHCP
# 端口配置交由 Docker 启动脚本处理（见 Dockerfile CMD override）

(
  echo "[post-init] 后台等待 vpnserver 就绪设置 DHCP..."
  for i in $(seq 1 30); do
    if vpncmd localhost:5555 /SERVER /PASSWORD:"${SPW}" /CMD ListenerList >/dev/null 2>&1; then
      vpncmd localhost:5555 /SERVER /HUB:DEFAULT /PASSWORD:"${SPW}" /CMD DhcpSet \
        /START:192.168.30.10 /END:192.168.30.200 /MASK:255.255.255.0 /EXPIRE:7200 \
        /DNS:8.8.8.8 /DNS2:8.8.4.4 /DOMAIN:local /GW:0.0.0.0 /LOG:no /PUSHROUTE:
      echo "[post-init] ✅ DhcpSet 完成"
      exit 0
    fi
    sleep 1
  done
  echo "[post-init] ⚠️ DHCP 设置超时"
) &
