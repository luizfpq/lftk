#!/bin/bash

set -e  # Sai imediatamente se um comando falhar

if [[ $# -ne 1 ]] || [[ "$1" != *@/* ]]; then
    echo "Uso: sudo $0 user@/caminho/da/pasta"
    exit 1
fi

INPUT="$1"
USER="${INPUT%@*}"
SHARE_PATH="${INPUT#*@}"

if [[ -z "$USER" ]] || [[ -z "$SHARE_PATH" ]] || [[ "$USER" == "$INPUT" ]]; then
    echo "Erro: formato inválido. Use user@/caminho"
    exit 1
fi

if [[ "${SHARE_PATH:0:1}" != "/" ]]; then
    echo "Erro: o caminho da pasta deve ser absoluto (começar com /)"
    exit 1
fi

echo "Configurando compartilhamento Samba para usuário '$USER' na pasta '$SHARE_PATH'..."

# Verifica se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script deve ser executado como root."
   exit 1
fi

# Instalar Samba se não estiver instalado
if ! command -v smbd >/dev/null 2>&1; then
    echo "Instalando o Samba..."
    apt update
    apt install -y samba
fi

# Criar o usuário no sistema, se não existir
if ! id "$USER" &>/dev/null; then
    echo "Criando usuário do sistema: $USER"
    useradd -m -s /bin/bash "$USER"
fi

# Criar o diretório de compartilhamento
mkdir -p "$SHARE_PATH"
chown "$USER:$USER" "$SHARE_PATH"
chmod 755 "$SHARE_PATH"

# Definir senha do Samba para o usuário
echo "Defina uma senha para o usuário Samba '$USER':"
smbpasswd -a "$USER"
smbpasswd -e "$USER"

# Nome do compartilhamento
SHARE_NAME=$(basename "$SHARE_PATH")

# Adicionar ao smb.conf (evitando duplicatas)
if grep -q "^\[$SHARE_NAME\]" /etc/samba/smb.conf; then
    echo "Aviso: compartilhamento [$SHARE_NAME] já existe no smb.conf."
else
    {
        echo ""
        echo "[$SHARE_NAME]"
        echo "   path = $SHARE_PATH"
        echo "   browseable = yes"
        echo "   writable = yes"
        echo "   guest ok = no"
        echo "   valid users = $USER"
        echo "   create mask = 0644"
        echo "   directory mask = 0755"
    } >> /etc/samba/smb.conf
fi

# Reiniciar serviços
systemctl restart smbd nmbd

echo ""
echo "✅ Compartilhamento Samba configurado com sucesso!"
echo "   - Pasta: $SHARE_PATH"
echo "   - Usuário: $USER"
echo "   - Nome do compartilhamento: $SHARE_NAME"
echo "   - Acesse via: \\\\IP_DA_VM\\$SHARE_NAME"