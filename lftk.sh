#!/bin/sh
# lftk.sh - Menu interativo do LinuxFineTunerKit
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

header() {
    clear
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║   LFTK - Linux Fine Tuner Kit                        ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
}

pause() {
    echo ""
    printf "Pressione ENTER para voltar ao menu..."
    read _
}

run_python() {
    script="$1"; shift
    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ python3 não encontrado. Instale com:"
        echo "  Alpine: apk add python3"
        echo "  Debian: apt install python3"
        return 1
    fi
    if [ ! -f "$script" ]; then
        echo "❌ $script não encontrado"; return 1
    fi
    echo "▶ $script"; echo "---"
    python3 "$script" "$@"
}

run_sh() {
    script="$1"; shift
    if [ ! -f "$script" ]; then
        echo "❌ $script não encontrado"; return 1
    fi
    echo "▶ $script"; echo "---"
    sh "$script" "$@"
}

menu_docker() {
    header
    echo "Docker"
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
    printf "Opção: "; read opt
    case $opt in
        1) run_python "$SCRIPT_DIR/install_docker_debian/install.py" ;;
        2) run_sh "$SCRIPT_DIR/install_docker_alpine/install.sh" ;;
        3) run_python "$SCRIPT_DIR/install_docker_debian/setup_memory.py" ;;
        4)
            echo "Uso: migrate.py backup [--sync user@host] [--stop]"
            printf "Argumentos (ou ENTER para backup local): "; read args
            run_python "$SCRIPT_DIR/backup_docker/migrate.py" backup $args
            ;;
        5) run_python "$SCRIPT_DIR/backup_docker/backup_volumes.py" ;;
        6) run_python "$SCRIPT_DIR/backup_docker/generate_restore.py" ;;
        7)
            printf "Ação [exportar/importar]: "; read action
            run_sh "$SCRIPT_DIR/install_docker_debian/export_containers.sh" "$action"
            ;;
        0) return ;;
    esac
    pause
}

menu_rede() {
    header
    echo "Rede & Firewall"
    echo ""
    echo "  1) Configurar IP estático (ironqui-*)"
    echo "  2) UFW - Aplicar whitelist de IPs"
    echo "  3) Mapear portas (Python/JSON)"
    echo "  4) Mapear portas (Shell/detalhado)"
    echo "  5) Auditor de portas (psutil)"
    echo "  6) Compartilhamento Samba"
    echo "  0) Voltar"
    echo ""
    printf "Opção: "; read opt
    case $opt in
        1) run_python "$SCRIPT_DIR/setup_static_ip.py" ;;
        2)
            printf "Arquivo de IPs: "; read ips
            printf "Arquivo de portas: "; read ports
            run_python "$SCRIPT_DIR/firewall/ufw_apply_whitelist.py" "$ips" "$ports"
            ;;
        3) run_python "$SCRIPT_DIR/firewall/map_ports.py" ;;
        4) run_sh "$SCRIPT_DIR/firewall/map_ports.sh" ;;
        5) run_python "$SCRIPT_DIR/firewall/port_auditor.py" ;;
        6)
            printf "Formato user@/caminho: "; read share
            run_sh "$SCRIPT_DIR/setup_smb_shares/setup.sh" "$share"
            ;;
        0) return ;;
    esac
    pause
}

menu_sistema() {
    header
    echo "Sistema & Hardware"
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
    printf "Opção: "; read opt
    case $opt in
        1) run_sh "$SCRIPT_DIR/install_base_packages/install.sh" ;;
        2) run_sh "$SCRIPT_DIR/setup_swap_vps/setup.sh" ;;
        3) run_python "$SCRIPT_DIR/setup_grub_savedefault/setup.py" ;;
        4) run_python "$SCRIPT_DIR/setup_notebook_server/disable_suspend.py" ;;
        5) run_python "$SCRIPT_DIR/setup_mount_softraid/mount.py" ;;
        6)
            echo "  a) NVIDIA padrão"
            echo "  b) NVIDIA Debian Testing"
            printf "Opção: "; read nv
            case $nv in
                a) run_sh "$SCRIPT_DIR/install_nvidia/install.sh" ;;
                b) run_sh "$SCRIPT_DIR/install_nvidia/install_testing.sh" ;;
            esac
            ;;
        7) run_sh "$SCRIPT_DIR/install_texlive/install.sh" ;;
        8) run_sh "$SCRIPT_DIR/install_npm_alpine/install.sh" ;;
        0) return ;;
    esac
    pause
}

menu_utils() {
    header
    echo "Utilitários"
    echo ""
    echo "  1) Importar chave GPG"
    echo "  2) Fix GTK IM Module (WhatsApp/Firefox)"
    echo "  3) Gerador de aliases"
    echo "  4) Instalar mongosh (Debian)"
    echo "  5) Preparar ISO para PXE (FOG)"
    echo "  6) Gerar usuários MySQL em batch"
    echo "  0) Voltar"
    echo ""
    printf "Opção: "; read opt
    case $opt in
        1)
            printf "Chave GPG: "; read key
            run_python "$SCRIPT_DIR/import_gpg_key/import.py" "$key"
            ;;
        2) run_python "$SCRIPT_DIR/fix_gtk_input/fix.py" ;;
        3) run_python "$SCRIPT_DIR/generate_aliases/generate.py" ;;
        4) run_python "$SCRIPT_DIR/install_mongosh_debian/install.py" ;;
        5)
            printf "Nome da ISO: "; read iso
            run_sh "$SCRIPT_DIR/setup_fog_pxe/prepare_iso.sh" "$iso"
            ;;
        6) run_python "$SCRIPT_DIR/generate_mysql_users/generate.py" ;;
        0) return ;;
    esac
    pause
}

while true; do
    header
    echo "  1) Docker"
    echo "  2) Rede & Firewall"
    echo "  3) Sistema & Hardware"
    echo "  4) Utilitários"
    echo ""
    echo "  0) Sair"
    echo ""
    printf "Opção: "; read choice
    case $choice in
        1) menu_docker ;;
        2) menu_rede ;;
        3) menu_sistema ;;
        4) menu_utils ;;
        0) echo "Até mais!"; exit 0 ;;
        *) echo "Opção inválida"; sleep 1 ;;
    esac
done
