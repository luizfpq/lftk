#!/usr/bin/env bash
# map_ports.sh
# Mapeia portas (TCP/UDP) e serviços/processos associados no Ubuntu.

set -euo pipefail

echo "== Ports & listeners (ss -tunlp) =="
# Show listening sockets with PID/program
ss -tunlp

echo
echo "== LSOF network (com mais detalhes) =="
if command -v lsof >/dev/null 2>&1; then
    lsof -i -P -n
else
    echo "lsof não encontrado (opcional). Instale com: sudo apt install lsof"
fi

echo
echo "== Detalhes por PID (porta -> PID -> cmdline / exe / systemd service se existir) =="
# Get PIDs from ss
PIDS=$(ss -tunlp 2>/dev/null | awk -F'[ ,]+' '/pid=/ { for(i=1;i<=NF;i++) if($i ~ /^pid=/) {split($i,a,"="); pid=a[2]; print pid}}' | sort -u)

if [ -z "$PIDS" ]; then
    echo "Nenhum listener encontrado (ou ss não retornou PIDs). Tente executar com sudo."
    exit 0
fi

for pid in $PIDS; do
    echo "----------------------------------------"
    echo "PID: $pid"
    if [ -r "/proc/$pid/cmdline" ]; then
        cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
        echo "Cmdline: ${cmdline:-(kernel/process)}"
    else
        echo "Cmdline: (não acessível)"
    fi

    if [ -L "/proc/$pid/exe" ]; then
        exe=$(readlink -f /proc/$pid/exe)
        echo "Executable: $exe"
    else
        echo "Executable: (não acessível)"
    fi

    # Try to find systemd service via /proc/<pid>/cgroup (system.slice entries)
    service_name=""
    if [ -r "/proc/$pid/cgroup" ]; then
        # grep for system.slice or name=systemd
        service_name=$(awk -F: '/system.slice/ {gsub(/^.*system.slice\//,"",$3); print $3; exit} /name=systemd/ {gsub(/^.*\//,"",$3); print $3; exit}' /proc/$pid/cgroup || true)
        # fallback: maybe ends with ".service"
        if [ -z "$service_name" ]; then
            service_name=$(awk -F: '{ if ($3 ~ /\.service/) { gsub(/^.*\//,"",$3); print $3; exit } }' /proc/$pid/cgroup || true)
        fi
    fi

    if [ -n "$service_name" ]; then
        echo "systemd service (via cgroup): $service_name"
        # show status summary
        if systemctl status "$service_name" &>/dev/null; then
            echo "systemctl: $(systemctl show -p ActiveState,SubState,MainPID --value $service_name 2>/dev/null | tr '\n' ' ' )"
        fi
    else
        echo "systemd service: (não detectado via cgroup)"
    fi

    # Show sockets for this PID
    echo "Sockets (ss -tunp filtering PID):"
    ss -tunp 2>/dev/null | grep -E "pid=${pid}," || true

done

echo
echo "== FIM =="
