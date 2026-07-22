# SoftEther Gateway
# 基于siomiz/softethervpn，配置通过环境变量注入，无需自定义脚本
# 端口改到5555（通过VPNCMD_SERVER环境变量自动完成）

FROM siomiz/softethervpn:latest

LABEL org.opencontainers.image.source="https://github.com/2061969365/softether-gateway"
LABEL org.opencontainers.image.description="SoftEther VPN Server gateway with 3x-ui coexistence (port 5555)"

EXPOSE 5555/tcp
EXPOSE 1194/udp
EXPOSE 500/udp
EXPOSE 4500/udp
EXPOSE 1701/udp
