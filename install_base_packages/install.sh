#!/bin/sh
# install.sh - Pacotes base para VPS free-tier (OCI)
# Suporta: apt (Debian/Ubuntu), apk (Alpine), dnf/yum (RHEL/Fedora)
set -e

detect_pkg_manager() {
    if command -v apk >/dev/null 2>&1; then echo "apk"
    elif command -v apt >/dev/null 2>&1; then echo "apt"
    elif command -v dnf >/dev/null 2>&1; then echo "dnf"
    elif command -v yum >/dev/null 2>&1; then echo "yum"
    else echo "unknown"; fi
}

PKG=$(detect_pkg_manager)

case "$PKG" in
    apt)
        apt update
        apt install -y \
            python3 python3-pip python3-venv \
            htop curl wget rsync tmux unzip \
            net-tools jq tree ncdu \
            bash-completion ca-certificates gnupg \
            plocate logrotate openssh-server
        ;;
    apk)
        apk update
        apk add \
            python3 py3-pip \
            htop curl wget rsync tmux unzip \
            net-tools jq tree ncdu \
            bash-completion ca-certificates gnupg \
            mlocate logrotate openssh
        ;;
    dnf|yum)
        $PKG install -y epel-release 2>/dev/null || true
        $PKG install -y \
            python3 python3-pip \
            htop curl wget rsync tmux unzip \
            net-tools jq tree ncdu \
            bash-completion ca-certificates gnupg2 \
            mlocate logrotate openssh-server
        ;;
    *)
        echo "❌ Gerenciador de pacotes não suportado."
        exit 1
        ;;
esac

command -v updatedb >/dev/null 2>&1 && updatedb 2>/dev/null || true

echo "✅ Pacotes base instalados ($PKG)."
