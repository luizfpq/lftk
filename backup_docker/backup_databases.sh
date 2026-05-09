#!/bin/sh
# backup_databases.sh - Detecta e faz dump de bancos em containers Docker
# Suporta: PostgreSQL, MySQL, MariaDB, MongoDB, SQLite
set -eu

REAL_HOME=$(eval echo "~${SUDO_USER:-$(whoami)}")
BACKUP_DIR="${1:-$REAL_HOME/docker_db_backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

echo "📁 Destino: $BACKUP_DIR"
echo "🔍 Procurando containers com bancos de dados..."
echo ""

dump_postgres() {
    container="$1"
    user=$(docker exec "$container" sh -c 'echo ${POSTGRES_USER:-postgres}')
    out="$BACKUP_DIR/${container}_postgres_${TIMESTAMP}.sql"
    echo "  💾 pg_dumpall -> $out"
    docker exec "$container" pg_dumpall -U "$user" > "$out"
}

dump_mysql() {
    container="$1"
    # Tenta root sem senha, depois com MYSQL_ROOT_PASSWORD
    out="$BACKUP_DIR/${container}_mysql_${TIMESTAMP}.sql"
    echo "  💾 mysqldump -> $out"
    docker exec "$container" sh -c \
        'mysqldump -u root -p"${MYSQL_ROOT_PASSWORD:-}" --all-databases 2>/dev/null || mysqldump -u root --all-databases' \
        > "$out"
}

dump_mongo() {
    container="$1"
    out="$BACKUP_DIR/${container}_mongo_${TIMESTAMP}"
    echo "  💾 mongodump -> $out/"
    docker exec "$container" sh -c \
        'mongodump --archive' > "${out}.archive"
}

dump_sqlite() {
    container="$1"
    db_path="$2"
    name=$(echo "$db_path" | sed 's|/|_|g')
    out="$BACKUP_DIR/${container}_sqlite_${name}_${TIMESTAMP}.sql"
    echo "  💾 sqlite3 .dump -> $out"
    docker exec "$container" sqlite3 "$db_path" .dump > "$out"
}

detect_and_dump() {
    container="$1"
    image=$(docker inspect --format '{{.Config.Image}}' "$container" | tr '[:upper:]' '[:lower:]')

    # Detecta por imagem
    case "$image" in
        *postgres*)
            echo "📦 $container [PostgreSQL]"
            dump_postgres "$container"
            return ;;
        *mysql*)
            echo "📦 $container [MySQL]"
            dump_mysql "$container"
            return ;;
        *mariadb*)
            echo "📦 $container [MariaDB]"
            dump_mysql "$container"
            return ;;
        *mongo*)
            echo "📦 $container [MongoDB]"
            dump_mongo "$container"
            return ;;
    esac

    # Detecta por processo rodando
    if docker exec "$container" pgrep -x postgres >/dev/null 2>&1; then
        echo "📦 $container [PostgreSQL]"
        dump_postgres "$container"
    elif docker exec "$container" pgrep -x mysqld >/dev/null 2>&1; then
        echo "📦 $container [MySQL/MariaDB]"
        dump_mysql "$container"
    elif docker exec "$container" pgrep -x mongod >/dev/null 2>&1; then
        echo "📦 $container [MongoDB]"
        dump_mongo "$container"
    elif docker exec "$container" sh -c 'find / -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null' | grep -q .; then
        echo "📦 $container [SQLite]"
        for db in $(docker exec "$container" sh -c 'find / -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null' | head -5); do
            dump_sqlite "$container" "$db"
        done
    fi
}

count=0
for container in $(docker ps -a --format '{{.Names}}'); do
    # Verifica se está rodando
    state=$(docker inspect --format '{{.State.Running}}' "$container")
    started_now=false
    if [ "$state" = "false" ]; then
        echo "⏸️  $container está parado, iniciando temporariamente..."
        docker start "$container" >/dev/null 2>&1 || continue
        sleep 2
        started_now=true
    fi
    if detect_and_dump "$container" 2>/dev/null; then
        count=$((count + 1))
    fi
    # Para novamente se foi ligado só para o backup
    if [ "$started_now" = "true" ]; then
        echo "  ⏹️  Parando $container novamente"
        docker stop "$container" >/dev/null 2>&1
    fi
done

echo ""
if [ "$count" -eq 0 ]; then
    echo "⚠️  Nenhum banco de dados detectado nos containers ativos."
else
    echo "✅ $count banco(s) exportado(s) em $BACKUP_DIR"
    ls -lh "$BACKUP_DIR"/*"$TIMESTAMP"* 2>/dev/null
fi
