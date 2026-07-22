#!/bin/bash
# post-init.sh — 在 entrypoint 末尾执行（vpnserver 启动前）
# 直接修改 vpn_server.config，避免 vpncmd 运行时操作的竞态和连接问题
# 使用纯 bash 遍历配置文件，不依赖 awk/python

CONFIG=/usr/vpnserver/vpn_server.config

echo "[post-init] ===== 修改前配置中的端口行 ====="
grep -B1 -A2 '\bPort\b' "$CONFIG" || echo "(无匹配)"

echo "[post-init] 重新生成配置文件（剔除 992/443 监听器，添加 5555）..."

# 逐行遍历，跳过 992/443 的 Listener 块
declare -a new_lines=()
skip=0

while IFS= read -r line; do
  if [[ "$line" =~ declare[[:space:]]+Listener ]]; then
    # 进入 Listener 块：暂存
    block=("$line")
    skip=0
    continue
  fi

  if [[ ${#block[@]} -gt 0 ]]; then
    block+=("$line")
    # 检查是否块结束（仅含 } 的行）
    if [[ "$line" =~ ^[[:space:]]*\}[[:space:]]*$ ]]; then
      # 检查整个块是否包含 Port 992 或 443
      block_text=$(printf "%s\n" "${block[@]}")
      if echo "$block_text" | grep -Eq '\bPort\s+(992|443)\b'; then
        echo "[post-init] 跳过监听器（含 Port 992/443）: $(echo "$block_text" | grep -o 'Port [0-9]*')"
        : # 不输出
      else
        for bline in "${block[@]}"; do
          new_lines+=("$bline")
        done
      fi
      block=()
    fi
    continue
  fi

  new_lines+=("$line")
done < "$CONFIG"

# 添加 5555 监听器
has_5555=0
for l in "${new_lines[@]}"; do
  if [[ "$l" =~ Port[[:space:]]+5555 ]]; then
    has_5555=1
    break
  fi
done

if [[ $has_5555 -eq 0 ]]; then
  echo "[post-init] 添加 Port 5555 监听器..."
  # 在最后一个仅含 } 的行前插入（即 root 块闭合）
  for idx in "${!new_lines[@]}"; do
    if [[ "${new_lines[$idx]}" =~ ^[[:space:]]*\}[[:space:]]*$ ]]; then
      last_close=$idx
    fi
  done
  # 在 last_close 之前插入 Listener 块
  insert_at=$last_close
  new_lines=("${new_lines[@]:0:$insert_at}"
    $'\tdeclare Listener'
    $'\t{'
    $'\t\tPort 5555'
    $'\t}'
    "${new_lines[@]:$insert_at}")
fi

# 写回
printf "%s\n" "${new_lines[@]}" > "$CONFIG"

echo "[post-init] ===== 修改后配置中的端口行 ====="
grep -B1 -A2 '\bPort\b' "$CONFIG" || echo "(空)"

echo "[post-init] ✅ 端口配置完成"

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
