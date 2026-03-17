#!/bin/bash
#
# Script de Instalação do Driver NVIDIA para Debian 12/13
# Baseado no guia oficial: https://docs.nvidia.com/datacenter/tesla/tesla-installation-notes/index.html#debian
#
# Uso: sudo bash install-nvidia-debian.sh
#

set -e  # Sai do script em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções de logging
log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERRO]${NC} $1"; }

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   log_error "Este script deve ser executado como root (use sudo)"
   exit 1
fi

# Detectar arquitetura
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCH_DEB="amd64"
    CUDA_ARCH="x86_64"
elif [[ "$ARCH" == "aarch64" ]]; then
    ARCH_DEB="arm64"
    CUDA_ARCH="sbsa"
else
    log_error "Arquitetura não suportada: $ARCH"
    exit 1
fi

# Detectar versão do Debian
DEBIAN_VERSION=$(lsb_release -rs)
if [[ "$DEBIAN_VERSION" != "12" && "$DEBIAN_VERSION" != "13" ]]; then
    log_warn "Versão do Debian não testada: $DEBIAN_VERSION (suporte oficial: 12 ou 13)"
    read -p "Deseja continuar? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

log_info "Sistema detectado: Debian $DEBIAN_VERSION ($ARCH_DEB)"

# =============================================================================
# MENU DE CONFIGURAÇÃO
# =============================================================================
echo ""
echo "=== Configuração da Instalação ==="
echo ""

# Escolher método de repositório
echo "Escolha o método de instalação do repositório:"
echo "1) Repositório de Rede (Recomendado - atualizações automáticas)"
echo "2) Repositório Local (Download manual do .deb)"
read -p "Opção [1]: " REPO_METHOD
REPO_METHOD=${REPO_METHOD:-1}

# Escolher tipo de kernel module
echo ""
echo "Escolha o tipo de módulo do kernel:"
echo "1) nvidia-open (Módulos abertos - recomendado para RTX 20+)"
echo "2) nvidia-proprietary (Módulos proprietários - legado/GTX)"
read -p "Opção [1]: " KERNEL_TYPE
KERNEL_TYPE=${KERNEL_TYPE:-1}

# Escolher tipo de instalação
echo ""
echo "Escolha o tipo de instalação:"
echo "1) Completa (Desktop + Compute - padrão)"
echo "2) Apenas Compute (Headless - sem componentes gráficos)"
echo "3) Apenas Desktop (Sem componentes de compute/CUDA)"
read -p "Opção [1]: " INSTALL_TYPE
INSTALL_TYPE=${INSTALL_TYPE:-1}

# Pinning de versão (opcional)
echo ""
read -p "Deseja travar em uma versão/branch específica do driver? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    read -p "Informe a versão ou branch (ex: 535, 550, production, newfeature): " PIN_VERSION
fi

# =============================================================================
# PRE-INSTALLATION
# =============================================================================
log_info "Executando ações de pré-instalação..."

# Atualizar pacotes
apt update -qq

# Instalar headers do kernel
log_info "Instalando headers do kernel..."
apt install -y linux-headers-$(uname -r) build-essential pkg-config

# Habilitar repositório contrib
if ! grep -q "contrib" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
    log_info "Habilitando repositório contrib..."
    add-apt-repository contrib -y
    apt update -qq
else
    log_info "Repositório contrib já habilitado"
fi

# =============================================================================
# CONFIGURAÇÃO DO REPOSITÓRIO NVIDIA
# =============================================================================
if [[ "$REPO_METHOD" == "1" ]]; then
    # === REPOSITÓRIO DE REDE ===
    log_info "Configurando repositório de rede NVIDIA..."
    
    # Baixar e instalar cuda-keyring
    KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/debian${DEBIAN_VERSION}/${CUDA_ARCH}/cuda-keyring_1.1-1_all.deb"
    
    if wget -q --spider "$KEYRING_URL"; then
        wget -O /tmp/cuda-keyring.deb "$KEYRING_URL"
        dpkg -i /tmp/cuda-keyring.deb
        rm -f /tmp/cuda-keyring.deb
    else
        # Fallback: instalar chave manualmente
        log_warn "Não foi possível baixar cuda-keyring, usando método alternativo..."
        wget -O /tmp/cuda-archive-keyring.gpg "https://developer.download.nvidia.com/compute/cuda/repos/debian${DEBIAN_VERSION}/${CUDA_ARCH}/cuda-archive-keyring.gpg"
        mv /tmp/cuda-archive-keyring.gpg /usr/share/keyrings/cuda-archive-keyring.gpg
        
        # Adicionar repositório manualmente
        echo "deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian${DEBIAN_VERSION}/${CUDA_ARCH}/ /" \
            > /etc/apt/sources.list.d/cuda-debian${DEBIAN_VERSION}-${ARCH_DEB}.list
    fi
    
    apt update -qq
    
else
    # === REPOSITÓRIO LOCAL ===
    log_info "Configurando repositório local NVIDIA..."
    
    read -p "Informe a versão do driver NVIDIA (ex: 535.129.03): " NVIDIA_VERSION
    
    LOCAL_REPO_URL="https://developer.download.nvidia.com/compute/nvidia-driver/${NVIDIA_VERSION}/local_installers/nvidia-driver-local-repo-debian${DEBIAN_VERSION}-${NVIDIA_VERSION}_${ARCH_DEB}.deb"
    
    log_info "Baixando repositório local: $LOCAL_REPO_URL"
    wget -O /tmp/nvidia-local-repo.deb "$LOCAL_REPO_URL"
    
    dpkg -i /tmp/nvidia-local-repo.deb
    cp /var/nvidia-driver-local-repo-debian${DEBIAN_VERSION}-${NVIDIA_VERSION}/nvidia-driver-*-keyring.gpg /usr/share/keyrings/ 2>/dev/null || true
    
    apt update -qq
    rm -f /tmp/nvidia-local-repo.deb
fi

# =============================================================================
# PINNING DE VERSÃO (OPCIONAL)
# =============================================================================
if [[ -n "$PIN_VERSION" ]]; then
    log_info "Configurando pinning para versão/branch: $PIN_VERSION"
    apt install -y "nvidia-driver-pinning-${PIN_VERSION}" 2>/dev/null || \
    log_warn "Pacote de pinning não encontrado. Verifique o nome: nvidia-driver-pinning-${PIN_VERSION}"
fi

# =============================================================================
# INSTALAÇÃO DO DRIVER
# =============================================================================
log_info "Iniciando instalação do driver NVIDIA..."

case "$INSTALL_TYPE" in
    2)
        # === COMPUTE-ONLY (HEADLESS) ===
        log_info "Instalando pacote compute-only (sem componentes gráficos)..."
        if [[ "$KERNEL_TYPE" == "1" ]]; then
            apt -V install -y nvidia-driver-cuda nvidia-kernel-open-dkms
        else
            apt -V install -y nvidia-driver-cuda nvidia-kernel-dkms
        fi
        ;;
    3)
        # === DESKTOP-ONLY ===
        log_info "Instalando pacote desktop-only (sem componentes de compute)..."
        if [[ "$KERNEL_TYPE" == "1" ]]; then
            apt -V install -y nvidia-driver nvidia-kernel-open-dkms
        else
            apt -V install -y nvidia-driver nvidia-kernel-dkms
        fi
        ;;
    *)
        # === INSTALAÇÃO COMPLETA ===
        log_info "Instalando driver completo..."
        if [[ "$KERNEL_TYPE" == "1" ]]; then
            apt -V install -y nvidia-open
        else
            apt -V install -y cuda-drivers
        fi
        ;;
esac

# =============================================================================
# PÓS-INSTALAÇÃO
# =============================================================================
log_info "Configurando módulos do kernel..."

# Garantir que o módulo está carregado
if lsmod | grep -q nvidia; then
    log_info "Módulo NVIDIA já carregado"
else
    log_info "Carregando módulo NVIDIA..."
    modprobe nvidia || true
fi

# Blacklist nouveau (se necessário)
if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist.conf 2>/dev/null; then
    log_info "Adicionando nouveau ao blacklist..."
    echo -e "blacklist nouveau\noptions nouveau modeset=0" >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf
    update-initramfs -u
fi

# =============================================================================
# FINALIZAÇÃO
# =============================================================================
echo ""
echo "============================================"
echo -e "${GREEN}Instalação concluída com sucesso!${NC}"
echo "============================================"
echo ""
echo "Próximos passos:"
echo "1. Reinicie o sistema: sudo reboot"
echo "2. Após reiniciar, verifique a instalação:"
echo "   - nvidia-smi          # Verificar driver e GPUs"
echo "   - glxinfo | grep OpenGL  # Verificar aceleração 3D"
echo ""
echo "Para atualizar o driver no futuro:"
echo "   sudo apt dist-upgrade"
echo ""
echo "Documentação oficial: https://docs.nvidia.com/datacenter/tesla/tesla-installation-notes/index.html"
echo ""

# Opção de reboot
read -p "Deseja reiniciar agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    log_info "Reiniciando sistema em 5 segundos..."
    sleep 5
    reboot
fi

exit 0