#!/bin/bash
# lftk.sh - Menu interativo do LinuxFineTunerKit
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${GREEN}LFTK - Linux Fine Tuner Kit${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

pause() {
    echo ""
    read -rp "Pressione ENTER para voltar ao menu..."
}

run_python() {
    local script="$1"; shift
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}python3 não encontrado. Instale com:${NC}"
        echo "  Alpine: apk add python3"
        echo "  Debian: apt install python3"
        return 1
    fi
    if [ ! -f "$script" ]; then
        echo -e "${RED}Erro: $script não encontrado${NC}"; return 1
    fi
    echo -e "${YELLOW}▶ $script${NC}"; echo "---"
    python3 "$script" "$@"
}

run_bash() {
    local script="$1"; shift
    if [ ! -f "$script" ]; then
        echo -e "${RED}Erro: $script não encontrado${NC}"; return 1
    fi
    echo -e "${YELLOW}▶ $script${NC}"; echo "---"
    bash "$script" "$@"
}

menu_docker() {
    header
    echo -e "${GREEN}Docker${NC}"
    echo ""
    echo "  1) Instalar Docker (Debian)"
    echo "  2) Instalar Docker (Alpine)"
    echo "  3) Configurar memória/swap para Docker"
    echo "  4) Backup & Migração (volumes + imagens + rsync)"
    echo "  5) Backup de volumes (simples)"
    echo "  6) Gerar docker-compose de restore"
    echo "  7) Exportar/Importar containers (legado)"
    echo "  0) Voltar"
    echo ""
    read -rp "Opção: " opt
    case $opt in
        1) run_python "$SCRIPT_DIR/install_docker_debian/install.py" ;;
        2) run_bash "$SCRIPT_DIR/install_docker_alpine/install.sh" ;;
        3) run_python "$SCRIPT_DIR/install_docker_debian/setup_memory.py" ;;
        4)
            echo -e "${CYAN}Uso: migrate.py backup [--sync user@host] [--stop]${NC}"
            read -rp "Argumentos (ou ENTER para backup local): " args
            run_python "$SCRIPT_DIR/backup_docker/migrate.py" backup $args
            ;;
        5) run_python "$SCRIPT_DIR/backup_docker/backup_volumes.py" ;;
        6) run_python "$SCRIPT_DIR/backup_docker/generate_restore.py" ;;
        7)
            read -rp "Ação [exportar/importar]: " action
            run_bash "$SCRIPT_DIR/install_docker_debian/export_containers.sh" "$action"
            ;;
        0) return ;;
    esac
    pause
}

menu_rede() {
    header
    echo -e "${GREEN}Rede & Firewall${NC}"
    echo ""
    echo "  1) Configurar IP estático (ironqui-*)"
    echo "  2) UFW - Aplicar whitelist de IPs"
    echo "  3) Mapear portas (Python/JSON)"
    echo "  4) Mapear portas (Bash/detalhado)"
    echo "  5) Auditor de portas (psutil)"
    echo "  6) Compartilhamento Samba"
    echo "  0) Voltar"
    echo ""
    read -rp "Opção: " opt
    case $opt in
        1) run_python "$SCRIPT_DIR/setup_static_ip.py" ;;
        2)
            read -rp "Arquivo de IPs: " ips
            read -rp "Arquivo de portas: " ports
            run_python "$SCRIPT_DIR/firewall/ufw_apply_whitelist.py" "$ips" "$ports"
            ;;
        3) run_python "$SCRIPT_DIR/firewall/map_ports.py" ;;
        4) run_bash "$SCRIPT_DIR/firewall/map_ports.sh" ;;
        5) run_python "$SCRIPT_DIR/firewall/port_auditor.py" ;;
        6)
            read -rp "Formato user@/caminho: " share
            run_bash "$SCRIPT_DIR/setup_smb_shares/setup.sh" "$share"
            ;;
        0) return ;;
    esac
    pause
}

menu_sistema() {
    header
    echo -e "${GREEN}Sistema & Hardware${NC}"
    echo ""
    echo "  1) Instalar pacotes base (multi-distro)"
    echo "  2) Criar swap em VPS"
    echo "  3) GRUB savedefault (dual-boot)"
    echo "  4) Desabilitar suspend ao fechar tampa"
    echo "  5) Montar RAID dinâmico (ldmtool)"
    echo "  6) Instalar drivers NVIDIA"
    echo "  7) Instalar TeX Live completo"
    echo "  8) Instalar NPM no Alpine (Nginx Proxy Manager)"
    echo "  0) Voltar"
    echo ""
    read -rp "Opção: " opt
    case $opt in
        1) run_bash "$SCRIPT_DIR/install_base_packages/install.sh" ;;
        2) run_bash "$SCRIPT_DIR/setup_swap_vps/setup.sh" ;;
        3) run_python "$SCRIPT_DIR/setup_grub_savedefault/setup.py" ;;
        4) run_python "$SCRIPT_DIR/setup_notebook_server/disable_suspend.py" ;;
        5) run_python "$SCRIPT_DIR/setup_mount_softraid/mount.py" ;;
        6)
            echo "  a) NVIDIA padrão"
            echo "  b) NVIDIA Debian Testing"
            read -rp "Opção: " nv
            case $nv in
                a) run_bash "$SCRIPT_DIR/install_nvidia/install.sh" ;;
                b) run_bash "$SCRIPT_DIR/install_nvidia/install_testing.sh" ;;
            esac
            ;;
        7) run_bash "$SCRIPT_DIR/install_texlive/install.sh" ;;
        8) run_bash "$SCRIPT_DIR/install_npm_alpine/install.sh" ;;
        0) return ;;
    esac
    pause
}

menu_utils() {
    header
    echo -e "${GREEN}Utilitários${NC}"
    echo ""
    echo "  1) Importar chave GPG"
    echo "  2) Fix GTK IM Module (WhatsApp/Firefox)"
    echo "  3) Gerador de aliases"
    echo "  4) Instalar mongosh (Debian)"
    echo "  5) Preparar ISO para PXE (FOG)"
    echo "  6) Gerar usuários MySQL em batch"
    echo "  0) Voltar"
    echo ""
    read -rp "Opção: " opt
    case $opt in
        1)
            read -rp "Chave GPG: " key
            run_python "$SCRIPT_DIR/import_gpg_key/import.py" "$key"
            ;;
        2) run_python "$SCRIPT_DIR/fix_gtk_input/fix.py" ;;
        3) run_python "$SCRIPT_DIR/generate_aliases/generate.py" ;;
        4) run_python "$SCRIPT_DIR/install_mongosh_debian/install.py" ;;
        5)
            read -rp "Nome da ISO: " iso
            run_bash "$SCRIPT_DIR/setup_fog_pxe/prepare_iso.sh" "$iso"
            ;;
        6) run_python "$SCRIPT_DIR/generate_mysql_users/generate.py" ;;
        0) return ;;
    esac
    pause
}

while true; do
    header
    echo "  1) 🐳 Docker"
    echo "  2) 🌐 Rede & Firewall"
    echo "  3) ⚙️  Sistema & Hardware"
    echo "  4) 🔧 Utilitários"
    echo ""
    echo "  0) Sair"
    echo ""
    read -rp "Opção: " choice
    case $choice in
        1) menu_docker ;;
        2) menu_rede ;;
        3) menu_sistema ;;
        4) menu_utils ;;
        0) echo -e "${GREEN}Até mais!${NC}"; exit 0 ;;
        *) echo -e "${RED}Opção inválida${NC}"; sleep 1 ;;
    esac
done
