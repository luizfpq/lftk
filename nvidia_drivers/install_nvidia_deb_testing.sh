#!/bin/bash

# Script de Instalação NVIDIA - Bypass de Autenticação para SHA-1 (Debian 2026)
# Otimizado para ignorar bloqueios de segurança em repositórios legados da NVIDIA.

set -e
trap 'log_error "Erro na linha $LINENO. O script foi interrompido."' ERR

# Cores e Logging
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
   log_error "Execute este script com sudo."
   exit 1
fi

# 1. Limpeza de Conflitos
log_info "Limpando configurações prévias..."
rm -f /etc/apt/sources.list.d/cuda*.list
rm -f /usr/share/keyrings/cuda-archive-keyring.gpg

# 2. Configuração Manual do Repositório (Trusted)
log_info "Configurando repositório NVIDIA como confiável para contornar SHA-1..."
# Adicionamos [trusted=yes] para que o APT aceite os pacotes mesmo com falha na assinatura GPG.
echo "deb [arch=amd64 trusted=yes] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /" > /etc/apt/sources.list.d/cuda-debian12-x86_64.list

# 3. Sincronização Forçada
log_info "Sincronizando repositórios..."
# Permitimos explicitamente repositórios inseguros na atualização.
apt update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true || log_warn "Aviso na sincronização ignorado."

# 4. Instalação com Bypass de Autenticação
log_info "Iniciando instalação (permitindo pacotes não autenticados)..."
# Usamos --allow-unauthenticated para contornar o erro que interrompeu o script anterior[cite: 1].
apt install -y -f --allow-unauthenticated nvidia-driver nvidia-cuda-toolkit nvidia-smi

# 5. Blacklist Nouveau
if ! grep -q "blacklist nouveau" /etc/modprobe.d/blacklist-nvidia-nouveau.conf 2>/dev/null; then
    log_info "Desabilitando o driver Nouveau..."
    echo -e "blacklist nouveau\noptions nouveau modeset=0" > /etc/modprobe.d/blacklist-nvidia-nouveau.conf
    update-initramfs -u
fi

log_info "======================================================"
log_info " PROCEDIMENTO CONCLUÍDO COM SUCESSO!"
log_info " Reinicie o sistema e execute: nvidia-smi"
log_info "======================================================"