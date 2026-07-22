# SoftEther Gateway
# 基于siomiz/softethervpn，修复 entrypoint 的 VPNCMD 数组解析 bug
# 配置通过环境变量注入 + post-init.sh 脚本完成

FROM siomiz/softethervpn:latest

LABEL org.opencontainers.image.source="https://github.com/2061969365/softether-gateway"
LABEL org.opencontainers.image.description="SoftEther VPN Server gateway with 3x-ui coexistence (port 5555)"

# 复制 post-init 脚本，修复 siomiz entrypoint 的数组解析 bug
# post-init.sh 在 entrypoint 末尾执行，后台等待 vpnserver 就绪后完成剩余配置
COPY scripts/post-init.sh /opt/scripts/post-init.sh
RUN chmod +x /opt/scripts/post-init.sh

EXPOSE 5555/tcp
EXPOSE 1194/udp
EXPOSE 500/udp
EXPOSE 4500/udp
EXPOSE 1701/udp
