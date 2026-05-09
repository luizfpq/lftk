#!/bin/sh
# setup.sh - Cria swapfile em VPS
set -e

SIZE="${1:-1G}"
SWAPFILE="/swapfile"

echo "📊 Swap atual:"
swapon --show 2>/dev/null || echo "  Nenhum swap ativo."

if [ -f "$SWAPFILE" ]; then
    echo "⚠️  $SWAPFILE já existe."
    exit 0
fi

echo "💾 Criando swap de $SIZE..."
fallocate -l "$SIZE" "$SWAPFILE" 2>/dev/null || dd if=/dev/zero of="$SWAPFILE" bs=1M count=$(echo "$SIZE" | sed 's/G/*1024/;s/M//' | bc) status=progress
chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE"
swapon "$SWAPFILE"

if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE swap swap defaults 0 0" >> /etc/fstab
fi

echo "✅ Swap de $SIZE ativo e persistente."
swapon --show
