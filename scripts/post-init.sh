#!/bin/bash
# post-init.sh — 在 entrypoint 末尾执行（vpnserver 启动前）
# 通过 sed 直接修改 vpn_server.config，避免 vpncmd 运行时操作的竞态和连接问题
# 第1部分：同步修改配置文件，第2部分：后台等待 vpnserver 就绪后设置 DHCP

CONFIG=/usr/vpnserver/vpn_server.config
echo "[post-init] 修改 vpn_server.config 监听端口..."

# 删除 992 监听器块（sed 多行模式：逐块匹配，含 Port 992 的整块删除）
# 使用 awk 更可靠：遍历声明块，跳过指定端口
awk '
/declare Listener/ {
  block = $0 "\n"
  in_block = 1
  next
}
in_block {
  block = block $0 "\n"
  if ($0 ~ /^[[:space:]]*}[[:space:]]*$/) {
    if (block !~ /Port 992/ && block !~ /Port 443/) {
      printf "%s", block
    }
    in_block = 0
    block = ""
  }
  next
}
!in_block { print }
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"

# 添加 5555 监听器（如果还没有）
if ! grep -q "Port 5555" "$CONFIG"; then
  # 在 root 块结束前插入
  sed -i '${/^}/i\\tdeclare Listener\n\t{\n\t\tPort 5555\n\t}
}' "$CONFIG"
fi

echo "[post-init] ✅ 端口配置完成（已删除992/443，添加5555）"

# ─────────────────────────────────────────────────────────────
# 第2部分：后台等待 vpnserver 就绪后设置 DHCP
# ─────────────────────────────────────────────────────────────
(
  echo "[post-init] 后台等待 vpnserver 就绪设置 DHCP..."
  for i in $(seq 1 30); do
    if vpncmd localhost /SERVER /PASSWORD:"${SPW}" /CMD ListenerList >/dev/null 2>&1; then
      vpncmd localhost /SERVER /HUB:DEFAULT /PASSWORD:"${SPW}" /CMD DhcpSet \
        /START:192.168.30.10 /END:192.168.30.200 /MASK:255.255.255.0 /EXPIRE:7200 \
        /DNS:8.8.8.8 /DNS2:8.8.4.4 /DOMAIN:local /GW:0.0.0.0 /LOG:no /PUSHROUTE:
      echo "[post-init] ✅ DhcpSet 完成"
      exit 0
    fi
    sleep 1
  done
  echo "[post-init] ⚠️ DHCP 设置超时"
) &
