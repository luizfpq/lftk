#!/bin/sh
set -e

echo "🐳 Instalando Docker no Alpine Linux..."

apk update
apk add docker docker-cli-compose

rc-update add docker default
service docker start

addgroup "${USER:-$(whoami)}" docker 2>/dev/null || true

echo "✅ Docker instalado e rodando."
echo "   docker compose disponível."
echo "   Faça logout/login para usar sem sudo."
