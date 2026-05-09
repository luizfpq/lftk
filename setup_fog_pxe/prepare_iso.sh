#!/bin/bash

# Verifica se o nome da ISO foi passado como argumento
if [ -z "$1" ]; then
    echo "Uso: $0 <nome_da_iso>"
    exit 1
fi

ISO_NAME=$1
ISO_PATH="/var/lib/fog/iso/$ISO_NAME"   # Caminho onde as ISOs serão armazenadas
PXE_CFG_PATH="/tftpboot/pxelinux.cfg/default"  # Caminho da configuração PXE (ajuste conforme necessário)

# Verifica se o arquivo ISO existe
if [ ! -f "$ISO_PATH" ]; then
    echo "Erro: A ISO '$ISO_NAME' não foi encontrada em $ISO_PATH."
    exit 1
fi

# Cria ponto de montagem e monta a ISO
MOUNT_POINT="/mnt/iso"
mkdir -p "$MOUNT_POINT"
mount -o loop "$ISO_PATH" "$MOUNT_POINT"

if [ $? -ne 0 ]; then
    echo "Erro ao montar a ISO."
    exit 1
fi

# Copia o conteúdo da ISO para o diretório do FOG, para ser usado no PXE
ISO_MOUNT_DEST="/var/www/html/fog/iso/$ISO_NAME"
mkdir -p "$ISO_MOUNT_DEST"
cp -r "$MOUNT_POINT"/* "$ISO_MOUNT_DEST"

# Desmonta a ISO
umount "$MOUNT_POINT"

# Atualiza o arquivo de configuração PXE para adicionar a entrada da nova ISO
echo "Adicionando a entrada para a ISO no arquivo de configuração PXE..."

cat >> "$PXE_CFG_PATH" << EOF
LABEL $ISO_NAME
    MENU LABEL Instalar $ISO_NAME
    KERNEL memdisk
    INITRD http://<ip-do-servidor-fog>/fog/iso/$ISO_NAME/boot/vmlinuz   # Ajuste conforme necessário
    APPEND iso raw
EOF

echo "ISO '$ISO_NAME' preparada para instalação via PXE."
