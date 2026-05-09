#!/bin/bash
# optimize.sh - Otimização para Ubuntu Server (VPS/dedicado)
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Execute como root"; exit 1
fi

echo "╔══════════════════════════════════════╗"
echo "║  Otimização Ubuntu Server            ║"
echo "╚══════════════════════════════════════╝"

# ─── 1. Desabilitar serviços desnecessários ───────────────────────────────────
echo ""
echo "⏹️  Desabilitando serviços desnecessários..."

DISABLE_SERVICES=(
    snapd snapd.socket snapd.seeded
    ModemManager
    networkd-dispatcher
    apport
    motd-news.timer
    fwupd
    udisks2
    accounts-daemon
    multipathd
)

for svc in "${DISABLE_SERVICES[@]}"; do
    if systemctl is-enabled "$svc" &>/dev/null; then
        systemctl disable --now "$svc" 2>/dev/null && echo "  ✅ $svc desabilitado"
    fi
done

# Remover snap se não estiver em uso
if command -v snap &>/dev/null && [ "$(snap list 2>/dev/null | wc -l)" -le 1 ]; then
    echo "  🗑️  Removendo snapd (sem snaps instalados)..."
    apt purge -y snapd 2>/dev/null
    rm -rf /snap /var/snap /var/lib/snapd
fi

# ─── 2. Sysctl - Tuning de kernel para VPS ───────────────────────────────────
echo ""
echo "🔧 Aplicando tuning de kernel..."

cat > /etc/sysctl.d/99-server-optimize.conf << 'EOF'
# Rede
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 4096
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1

# Memória
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# Segurança
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
EOF

sysctl --system >/dev/null 2>&1
echo "  ✅ sysctl aplicado"

# ─── 3. Journald - limitar uso de disco ──────────────────────────────────────
echo ""
echo "📝 Otimizando journald..."

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/size-limit.conf << 'EOF'
[Journal]
SystemMaxUse=100M
MaxRetentionSec=7day
Compress=yes
EOF

systemctl restart systemd-journald
journalctl --vacuum-size=100M --vacuum-time=7d >/dev/null 2>&1
echo "  ✅ Logs limitados a 100M / 7 dias"

# ─── 4. Netdata - reduzir overhead se presente ───────────────────────────────
if systemctl is-active netdata &>/dev/null; then
    echo ""
    echo "📊 Otimizando netdata (reduzindo coleta)..."

    NETDATA_CONF="/etc/netdata/netdata.conf"
    if [ -f "$NETDATA_CONF" ]; then
        # Aumentar intervalo de coleta e reduzir histórico
        grep -q "update every" "$NETDATA_CONF" || cat >> "$NETDATA_CONF" << 'EOF'

[global]
    update every = 5
    memory mode = dbengine
    page cache size = 32
    dbengine multihost disk space = 256

[plugins]
    apps = no
    cgroups = no
EOF
        systemctl restart netdata
        echo "  ✅ Netdata: coleta a cada 5s, apps.plugin desabilitado"
    fi
fi

# ─── 5. Limpar cache e pacotes ────────────────────────────────────────────────
echo ""
echo "🧹 Limpando sistema..."

apt autoremove -y >/dev/null 2>&1
apt clean >/dev/null 2>&1

# Limpar logs antigos
find /var/log -name "*.gz" -delete 2>/dev/null
find /var/log -name "*.1" -delete 2>/dev/null

# Limpar cache de thumbnails/tmp
rm -rf /tmp/* 2>/dev/null
echo "  ✅ Cache limpo"

# ─── 6. Limites de sistema ────────────────────────────────────────────────────
echo ""
echo "📈 Ajustando limites de arquivos abertos..."

grep -q "* soft nofile" /etc/security/limits.conf || cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 65535
* hard nofile 65535
EOF

# ─── Resumo ──────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "✅ Otimização concluída!"
echo ""
echo "Mudanças aplicadas:"
echo "  • Serviços desnecessários desabilitados"
echo "  • Kernel tunado para rede e memória"
echo "  • Journald limitado (100M/7d)"
echo "  • Cache e logs antigos limpos"
if systemctl is-active netdata &>/dev/null; then
    echo "  • Netdata: apps.plugin desabilitado (era o maior consumidor)"
fi
echo ""
echo "⚠️  Recomendação: reboot para aplicar todos os limites"
