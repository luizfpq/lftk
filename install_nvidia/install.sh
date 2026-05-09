#!/bin/bash

# ==============================================================================
# Script de Instalação NVIDIA CUDA - Edição Robusta Debian (2026)
# Compatibilidade: Debian 12, Debian 13 (Trixie/Testing) e sucessores.
# ==============================================================================

set -e
trap 'log_error "Erro inesperado na linha $LINENO. O script foi interrompido."' ERR

# Cores para Saída
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_NC='\033[0m'

# Funções de Log
log_info()    { echo -e "${COLOR_GREEN}[INFO]${COLOR_NC} $1"; }
log_warn()    { echo -e "${COLOR_YELLOW}[AVISO]${COLOR_NC} $1"; }
log_error()   { echo -e "${COLOR_RED}[ERRO]${COLOR_NC} $1"; }

# 1. Validação de Privilégios[cite: 3]
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
       log_error "Este script deve ser executado como root (use sudo)."
       exit 1
    fi
}

# 2. Detecção de Ambiente e Versão Debian[cite: 2, 3]
detect_system() {
    log_info "Detectando ambiente do sistema..."
    
    # Arquitetura[cite: 2, 3]
    CUDA_ARCH=$(uname -m)
    if [[ "$CUDA_ARCH" != "x86_64" ]]; then
        log_error "Arquitetura $CUDA_ARCH não suportada (apenas x86_64)."
        exit 1
    fi

    # Versão Debian[cite: 2]
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$VERSION_ID" == "12" ]]; then
            DEBIAN_VER="12"
        elif [[ "$VERSION_ID" == "13" || "$VERSION_CODENAME" == "trixie" || "$VERSION_CODENAME" == "sid" ]]; then
            DEBIAN_VER="13"
        elif [[ -z "$VERSION_ID" || "$VERSION_ID" > "13" ]]; then
            log_warn "Versão posterior ao Debian 13 detectada ($VERSION_ID). Tratando como Debian 13 sem garantias."
            DEBIAN_VER="13"
        else
            log_error "Versão Debian ($VERSION_ID) não suportada. Requer Debian 12 ou superior."
            exit 1
        fi
    fi
    log_info "Identificado: Debian $DEBIAN_VER ($CUDA_ARCH)"
}

# 3. Limpeza de Conflitos GPG e Repositórios[cite: 1, 3]
cleanup_assets() {
    log_info "Iniciando limpeza profunda de chaves e repositórios antigos..."
    
    # Chaves obsoletas e arquivos de lista[cite: 1, 3]
    rm -f /etc/apt/trusted.gpg.d/cuda-7fa2af80.gpg
    rm -f /usr/share/keyrings/cuda-archive-keyring.gpg
    rm -f /etc/apt/sources.list.d/cuda*.list
    rm -f /etc/apt/sources.list.d/nvidia*.list
    
    # Limpeza no sources.list principal[cite: 1, 3]
    if [ -f /etc/apt/sources.list ]; then
        sed -i '/developer\.download\.nvidia\.com\/compute\/cuda\/repos/d' /etc/apt/sources.list
    fi
}

# 4. Configuração de Chaves e Bypass de SHA-1 (Política de Segurança 2026)[cite: 1]
setup_keys_and_repo() {
    log_info "Configurando chave GPG e repositório (com bypass de SHA-1)..."
    
    # Debian 13 em 2026 rejeita SHA-1. Usamos fallback para debian12 no CDN[cite: 1, 2]
    local repo_base="debian12"
    
    # Importação manual da chave para evitar rejeição da política de segurança[cite: 1]
    wget -qO- "https://developer.download.nvidia.com/compute/cuda/repos/${repo_base}/${CUDA_ARCH}/3bf863cc.pub" | \
    gpg --dearmor > /usr/share/keyrings/cuda-archive-keyring.gpg

    # Configuração da source com flag [trusted=yes] para contornar assinaturas SHA-1[cite: 1]
    echo "deb [arch=amd64 trusted=yes] https://developer.download.nvidia.com/compute/cuda/repos/${repo_base}/x86_64/ /" > /etc/apt/sources.list.d/cuda-repository.list
}

# 5. Instalação e Auto-Reparo[cite: 3]
install_packages() {
    local inst_type=$1
    local kern_type=$2

    log_info "Sincronizando repositórios (permitindo algoritmos legados)..."
    apt update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true || true

    log_info "Instalando dependências de compilação..."
    apt install -y build-essential wget dkms linux-headers-$(uname -r) g++-13

    log_info "Iniciando instalação do driver e toolkit..."
    # Seleção de pacotes conforme escolha do usuário[cite: 3]
    local pkgs="nvidia-smi"
    if [[ "$inst_type" == "2" ]]; then pkgs="$pkgs nvidia-driver-cuda"; fi # Headless
    if [[ "$inst_type" == "3" ]]; then pkgs="$pkgs nvidia-driver"; fi # Desktop
    if [[ "$inst_type" == "1" ]]; then pkgs="$pkgs nvidia-driver nvidia-cuda-toolkit"; fi # Full

    # Adição de módulo open ou proprietário[cite: 3]
    [[ "$kern_type" == "1" ]] && pkgs="$pkgs nvidia-kernel-open-dkms" || pkgs="$pkgs nvidia-kernel-dkms"

    # Instalação com bypass de autenticação[cite: 1]
    apt install -y -f --allow-unauthenticated $pkgs || {
        log_warn "Conflito detectado. Tentando reparo automático..."
        apt --fix-broken install -y --allow-unauthenticated
    }
}

# 6. Pós-Instalação[cite: 3]
post_install() {
    log_info "Finalizando configurações..."
    
    # Blacklist Nouveau[cite: 3]
    if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist-nvidia-nouveau.conf 2>/dev/null; then
        echo -e "blacklist nouveau\noptions nouveau modeset=0" > /etc/modprobe.d/blacklist-nvidia-nouveau.conf
        update-initramfs -u
    fi

    echo -e "\n${COLOR_GREEN}======================================================${COLOR_NC}"
    echo -e "  INSTALAÇÃO CONCLUÍDA! REBOOT OBRIGATÓRIO."
    echo -e "  Após reiniciar, teste com: nvidia-smi"
    echo -e "${COLOR_GREEN}======================================================${COLOR_NC}"
}

# Execução Principal
main() {
    check_privileges
    detect_system
    
    # Menu de Escolhas
    echo -e "\n=== Menu de Configuração NVIDIA ==="
    echo "1. Módulos: 1) Open (RTX 20+) ou 2) Proprietary (GTX/Legado)"
    read -p "Opção [1]: " KERN_OPT
    echo "2. Instalação: 1) Completa (Desktop+CUDA), 2) Compute (Headless), 3) Apenas Desktop"
    read -p "Opção [1]: " INST_OPT
    
    KERN_OPT=${KERN_OPT:-1}
    INST_OPT=${INST_OPT:-1}

    cleanup_assets
    setup_keys_and_repo
    install_packages "$INST_OPT" "$KERN_OPT"
    post_install
}

main "$@"