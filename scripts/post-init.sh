#!/bin/bash
# post-init.sh — 在 entrypoint 末尾执行（vpnserver 启动前）
# 利用 siomiz 的 /opt/scripts/ 机制，在后台等待 vpnserver 就绪后执行剩余配置
# 修复 siomiz entrypoint 的 VPNCMD_SERVER 数组解析 bug（只取 CMD[0]）

(
  echo "[post-init] 等待 vpnserver 就绪..."

  for i in $(seq 1 30); do
    if vpncmd localhost /SERVER /PASSWORD:"${SPW}" /CMD ListenerList >/dev/null 2>&1; then
      echo "[post-init] vpnserver 就绪，执行剩余配置..."

      # 删除 992 监听器（siomiz 的 VPNCMD_SERVER bug 导致这步被跳过）
      vpncmd localhost /SERVER /PASSWORD:"${SPW}" /CMD ListenerDelete 992
      echo "[post-init] ListenerDelete 992 done"

      # 创建 5555 监听器（同样被 bug 跳过）
      vpncmd localhost /SERVER /PASSWORD:"${SPW}" /CMD ListenerCreate 5555
      echo "[post-init] ListenerCreate 5555 done"

      # DHCP 配置：不推默认网关（同样被 siomiz 的 VPNCMD_HUB bug 导致后面的参数被跳过）
      vpncmd localhost /SERVER /HUB:DEFAULT /PASSWORD:"${SPW}" /CMD DhcpSet \
        /START:192.168.30.10 \
        /END:192.168.30.200 \
        /MASK:255.255.255.0 \
        /EXPIRE:7200 \
        /DNS:8.8.8.8 \
        /DNS2:8.8.4.4 \
        /DOMAIN:local \
        /GW:0.0.0.0 \
        /LOG:no \
        /PUSHROUTE:
      echo "[post-init] DhcpSet done"

      # 确认结果
      echo "[post-init] ===== 当前监听端口 ====="
      vpncmd localhost /SERVER /PASSWORD:"${SPW}" /CMD ListenerList

      echo "[post-init] 配置完成 ✅"
      exit 0
    fi
    sleep 1
  done

  echo "[post-init] ⚠️ 超时：vpnserver 30秒内未就绪"
) &

# 注意：& 让脚本在后台运行，不阻塞 entrypoint 的 exec
