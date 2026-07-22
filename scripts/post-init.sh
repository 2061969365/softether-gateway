#!/bin/bash
# post-init.sh — 后台完整初始化 SoftEther VPN Server
# 由于 siomiz entrypoint 的 ExtOptionSet 会杀死 vpnserver 进程，
# 导致 SPW/USERS/VPNCMD 等环境变量全部不生效，所以所有配置都在此完成。

(
  echo "[post-init] 等待 vpnserver 就绪..."

  # 第 1 步：等待 vpnserver 启动（连接无密码模式，因为 entrypoint 没设上密码）
  for i in $(seq 1 30); do
    if vpncmd localhost:5555 /SERVER /CMD ListenerList >/dev/null 2>&1; then
      echo "[post-init] vpnserver 就绪（${i}秒）"
      break
    fi
    if [ $i -eq 30 ]; then
      echo "[post-init] ⚠️ vpnserver 未就绪，跳过初始化"
      exit 1
    fi
    sleep 1
  done

  # 第 2 步：设置管理密码
  if [ -n "${SPW}" ]; then
    echo "[post-init] 设置管理密码..."
    echo "${SPW}" | vpncmd localhost:5555 /SERVER /CMD ServerPasswordSet
  fi

  # 第 3 步：配置端口 — 删 443/992，保留 5555
  echo "[post-init] 删除端口 443..."
  vpncmd localhost:5555 /SERVER /PASSWORD:"${SPW}" /CMD ListenerDelete 443

  echo "[post-init] 删除端口 992..."
  vpncmd localhost:5555 /SERVER /PASSWORD:"${SPW}" /CMD ListenerDelete 992

  # 第 4 步：创建用户（USERS 格式：user1:pass1;user2:pass2）
  if [ -n "${USERS}" ]; then
    echo "[post-init] 创建用户..."
    IFS=';' read -ra USER_LIST <<< "${USERS}"
    for user_entry in "${USER_LIST[@]}"; do
      IFS=':' read -r username userpass <<< "${user_entry}"
      if [ -n "${username}" ]; then
        vpncmd localhost:5555 /SERVER /HUB:DEFAULT /PASSWORD:"${SPW}" /CMD UserCreate "${username}" /GROUP:none /REALNAME:"" /NOTE:"" >/dev/null 2>&1
        vpncmd localhost:5555 /SERVER /HUB:DEFAULT /PASSWORD:"${SPW}" /CMD UserPasswordSet "${username}" /PASSWORD:"${userpass}" >/dev/null 2>&1
        echo "[post-init] 用户 ${username} 创建完成"
      fi
    done
  fi

  # 第 5 步：配置 DHCP — 不设默认网关（GW:0.0.0.0），防止路由劫持
  echo "[post-init] 配置 DHCP..."
  vpncmd localhost:5555 /SERVER /HUB:DEFAULT /PASSWORD:"${SPW}" /CMD DhcpSet \
    /START:192.168.30.10 /END:192.168.30.200 /MASK:255.255.255.0 /EXPIRE:7200 \
    /DNS:8.8.8.8 /DNS2:8.8.4.4 /DOMAIN:local /GW:0.0.0.0 /LOG:no /PUSHROUTE:

  # 标记初始化完成（供 CI 和 healthcheck 使用）
  touch /tmp/post-init.done
  echo "[post-init] ✅ 全部初始化完成"
) &
