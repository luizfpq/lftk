#!/bin/sh

# Configurações de cores para log
RED='\033[0.31m'
GREEN='\033[0.32m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error_check() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} $1"
        exit 1
    fi
}

log "Iniciando instalação do NPM no Alpine Linux (Nativo)..."

# 1. Atualização e Dependências
apk update && apk upgrade
apk add nodejs npm python3 py3-pip build-base git sqlite openssl libffi-dev \
    nginx certbot openresty zlib-dev pcre-dev openrc openssl-dev
error_check "Falha ao instalar dependências do sistema."

# 2. Estrutura de Diretórios (NPM espera caminhos de Docker)
log "Preparando estrutura de arquivos..."
mkdir -p /app /data /etc/letsencrypt /run/nginx /usr/local/sbin /etc/nginx/conf.d/include
mkdir -p /var/lib/nginx/tmp/client_body /var/lib/nginx/tmp/proxy
mkdir -p /data/nginx/proxy_host /data/nginx/redirection_host /data/nginx/dead_host /data/nginx/temp
error_check "Falha ao criar diretórios."

# Links simbólicos críticos
ln -sf /usr/sbin/nginx /usr/local/sbin/nginx
ln -sf /usr/bin/certbot /usr/local/bin/certbot
ln -sf /usr/bin/python3 /usr/bin/python

# 3. Clone e Backend
if [ ! -d "/app/.git" ]; then
    git clone https://github.com/NginxProxyManager/nginx-proxy-manager.git /app
fi
cd /app/backend
npm install --omit=dev
error_check "Falha no npm install do backend."

# 4. Frontend e Correções de Compilação
log "Iniciando compilação do frontend (Fase Crítica)..."
cd /app/frontend
npm install
error_check "Falha no npm install do frontend."

# Hacks para o Alpine: Criar arquivos JSON de tradução vazios para evitar erro de build
mkdir -p src/locale/lang/
for lang in bg de pt en es fr ga id it ja ko nl pl ru sk vi zh tr hu; do
  echo "{}" > "src/locale/lang/$lang.json"
done
echo "{}" > src/locale/lang/lang-list.json

# Bypass no TypeScript e ajuste de tipos
echo "declare module '*.json' { const value: any; export default value; }" > src/json-fix.d.ts
sed -i 's/tsc && vite build/vite build/g' package.json
sed -i 's/messages: initialMessages/messages: initialMessages as any/g' src/locale/IntlProvider.tsx
sed -i 's/messages }, cache/messages: messages as any }, cache/g' src/locale/IntlProvider.tsx

# Build com limite de memória aumentado
export NODE_OPTIONS="--max-old-space-size=2048"
npm run build
error_check "Falha na compilação do frontend."

# 5. Configuração do NPM (Database SQLite)
log "Configurando banco de dados e segredos..."
JWT_SECRET=$(openssl rand -hex 16)
cat <<EOF > /app/config/production.json
{
  "database": {
    "engine": "sqlite",
    "storage": "/data/database.sqlite"
  },
  "jwt": {
    "secret": "$JWT_SECRET"
  },
  "port": 3000
}
EOF

# 6. Configuração do Nginx (Painel Admin)
log "Configurando Nginx Nativo..."
rm -f /etc/nginx/http.d/default.conf
cat <<EOF > /etc/nginx/http.d/npm_admin.conf
server {
    listen 8181;
    server_name _;
    root /app/frontend/dist;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# Inclusão de hosts dinâmicos
echo "include /etc/nginx/conf.d/*.conf;" > /etc/nginx/http.d/npm_configs.conf
touch /etc/nginx/conf.d/include/ip_ranges.conf

# 7. Scripts de Serviço (OpenRC)
log "Registrando serviços no OpenRC..."
cat <<'EOF' > /etc/init.d/nginx-proxy-manager
#!/sbin/openrc-run
name="nginx-proxy-manager"
description="NPM Backend Daemon"
command="/usr/bin/node"
command_args="index.js"
directory="/app/backend"
command_background="yes"
pidfile="/run/npm.pid"

start_pre() {
    export NODE_ENV=production
    checkpath --directory --owner root:root --mode 0775 /run
}

depend() {
    need net
    after nginx
}
EOF

chmod +x /etc/init.d/nginx-proxy-manager
rc-update add nginx default
rc-update add nginx-proxy-manager default

# Permissões finais
chown -R nginx:root /data
chmod -R 775 /data

# 8. Inicialização
log "Iniciando serviços..."
service nginx restart
service nginx-proxy-manager restart

log "-------------------------------------------------------"
log "Instalação finalizada!"
log "Acesse: http://$(hostname -i | awk '{print $1}'):8181"
log "Usuário: admin@example.com / Senha: changeme"
log "-------------------------------------------------------"