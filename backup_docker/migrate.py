#!/usr/bin/env python3
"""
Docker Backup & Migration Tool
Faz backup de volumes, exporta imagens customizadas, gera compose de restore,
e sincroniza tudo via rsync para um servidor remoto.

Uso:
  python3 docker_migrate.py backup                     # Backup local apenas
  python3 docker_migrate.py backup --sync user@host    # Backup + rsync para remoto
  python3 docker_migrate.py restore                    # Restaura no servidor atual
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import docker
    import yaml
except ImportError:
    print("❌ Dependências faltando. Instale com: pip install -r requirements.txt")
    sys.exit(1)


BACKUP_BASE = Path.home() / "docker_backups"


def safe_name(name: str) -> str:
    return name.replace("/", "_").replace(":", "_")


def get_client():
    try:
        client = docker.from_env()
        client.ping()
        return client
    except Exception as e:
        print(f"❌ Erro ao conectar ao Docker: {e}")
        sys.exit(1)


def is_custom_image(image) -> bool:
    """Detecta se a imagem é customizada (build local ou sem registry público)."""
    if not image.tags:
        return True
    for tag in image.tags:
        # Imagens oficiais: nome:tag ou library/nome:tag
        # Imagens de registry: registry.com/nome:tag
        parts = tag.split("/")
        if len(parts) == 1:
            return False  # ex: nginx:latest (oficial)
        if parts[0] in ("library", "docker.io"):
            return False
        if "." in parts[0] or ":" in parts[0]:
            return False  # ex: ghcr.io/user/img (registry público)
    return True


def backup_volumes(client):
    """Faz backup dos volumes de todos os containers."""
    print("\n📦 Fazendo backup dos volumes...")
    containers = client.containers.list(all=True)
    if not containers:
        print("  ⚠️  Nenhum container encontrado.")
        return

    count = 0
    for container in containers:
        inspect = client.api.inspect_container(container.id)
        mounts = inspect.get("Mounts", [])
        if not mounts:
            continue

        image_tags = container.image.tags if container.image.tags else []
        image_name = safe_name(image_tags[0] if image_tags else container.image.short_id)
        container_backup_dir = BACKUP_BASE / image_name / "data"
        container_backup_dir.mkdir(parents=True, exist_ok=True)

        print(f"  📦 {container.name} ({image_name})")

        for mount in mounts:
            source = mount.get("Source")
            destination = mount.get("Destination")
            if not source or not os.path.isdir(source):
                continue

            target_dir = container_backup_dir / safe_name(destination.strip("/"))
            try:
                with tempfile.TemporaryDirectory(dir=container_backup_dir.parent) as tmp:
                    temp_backup = Path(tmp) / target_dir.name
                    shutil.copytree(source, temp_backup, symlinks=True)
                    if target_dir.exists():
                        shutil.rmtree(target_dir)
                    shutil.move(str(temp_backup), str(target_dir))
                count += 1
                print(f"     ✅ {destination}")
            except Exception as e:
                print(f"     ❌ {destination}: {e}")

    print(f"  📊 {count} volume(s) copiado(s)")


def export_images(client):
    """Exporta imagens customizadas (build local) para .tar.gz."""
    print("\n🖼️  Exportando imagens customizadas...")
    images_dir = BACKUP_BASE / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    containers = client.containers.list(all=True)
    exported = set()
    count = 0

    for container in containers:
        image = container.image
        if not image.tags:
            continue
        tag = image.tags[0]
        if tag in exported:
            continue
        if not is_custom_image(image):
            continue

        exported.add(tag)
        filename = images_dir / f"{safe_name(tag)}.tar.gz"
        print(f"  💾 {tag} -> {filename.name}")

        try:
            with open(filename, "wb") as f:
                subprocess.run(
                    ["docker", "save", tag],
                    stdout=subprocess.PIPE, check=True
                ).stdout
                # Usar pipe com gzip para comprimir
                save = subprocess.Popen(
                    ["docker", "save", tag], stdout=subprocess.PIPE
                )
                subprocess.run(
                    ["gzip"], stdin=save.stdout, stdout=f, check=True
                )
                save.wait()
                if save.returncode != 0:
                    raise subprocess.CalledProcessError(save.returncode, "docker save")
            count += 1
            print(f"     ✅ Exportada")
        except Exception as e:
            print(f"     ❌ Erro: {e}")
            if filename.exists():
                filename.unlink()

    if count == 0:
        print("  ℹ️  Nenhuma imagem customizada encontrada (todas são públicas).")
    else:
        print(f"  📊 {count} imagem(ns) exportada(s)")


def generate_compose(client):
    """Gera docker-compose.restore.yml para recriar os containers."""
    print("\n📝 Gerando docker-compose.restore.yml...")
    compose = {"version": "3.9", "services": {}}

    containers = client.containers.list(all=True)
    for c in containers:
        inspect = client.api.inspect_container(c.id)
        image = inspect["Config"]["Image"]
        container_name = inspect["Name"].lstrip("/")
        image_dir = safe_name(image)
        mounts = inspect.get("Mounts", [])
        ports = inspect["HostConfig"].get("PortBindings") or {}
        envs = inspect["Config"].get("Env") or []
        networks = list(inspect["NetworkSettings"]["Networks"].keys())

        service = {
            "image": image,
            "container_name": container_name,
            "restart": "unless-stopped",
        }

        # Volumes
        if mounts:
            volumes = []
            for m in mounts:
                src = f"./{image_dir}/data/{safe_name(m['Destination'].strip('/'))}"
                volumes.append(f"{src}:{m['Destination']}")
            service["volumes"] = volumes

        # Portas
        if ports:
            service_ports = []
            for port, binds in ports.items():
                if binds:
                    for b in binds:
                        service_ports.append(f"{b['HostPort']}:{port}")
            if service_ports:
                service["ports"] = service_ports

        # Variáveis de ambiente
        if envs:
            service["environment"] = envs

        # Networks (exceto default bridge)
        non_default = [n for n in networks if n not in ("bridge", "host", "none")]
        if non_default:
            service["networks"] = non_default

        compose["services"][container_name] = service

    # Declarar networks usadas
    all_networks = set()
    for svc in compose["services"].values():
        all_networks.update(svc.get("networks", []))
    if all_networks:
        compose["networks"] = {n: {"external": True} for n in all_networks}

    compose_file = BACKUP_BASE / "docker-compose.restore.yml"
    with open(compose_file, "w") as f:
        yaml.dump(compose, f, sort_keys=False, default_flow_style=False)

    print(f"  ✅ {compose_file}")


def generate_restore_script():
    """Gera script de restore para o servidor destino."""
    script = BACKUP_BASE / "restore.sh"
    script.write_text("""\
#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "🔄 Restaurando imagens customizadas..."
if [ -d images ]; then
    for img in images/*.tar.gz; do
        [ -f "$img" ] || continue
        echo "  📥 Carregando $img"
        gunzip -c "$img" | docker load
    done
fi

echo ""
echo "🚀 Subindo containers..."
docker compose -f docker-compose.restore.yml up -d

echo ""
echo "✅ Restore concluído!"
docker ps
""")
    script.chmod(0o755)
    print(f"\n📜 Script de restore gerado: {script}")


def sync_to_remote(remote: str, port: int = 22):
    """Sincroniza backup para servidor remoto via rsync."""
    print(f"\n🔄 Sincronizando para {remote}...")

    remote_path = f"{remote}:~/docker_backups/"
    cmd = [
        "rsync", "-avz", "--progress", "--delete",
        "-e", f"ssh -p {port}",
        f"{BACKUP_BASE}/",
        remote_path,
    ]

    print(f"  $ {' '.join(cmd)}")
    result = subprocess.run(cmd)
    if result.returncode == 0:
        print(f"  ✅ Sincronização concluída para {remote}")
    else:
        print(f"  ❌ rsync falhou (código {result.returncode})")
        sys.exit(1)


def cmd_backup(args):
    """Executa backup completo."""
    BACKUP_BASE.mkdir(parents=True, exist_ok=True)
    client = get_client()

    print(f"📁 Diretório de backup: {BACKUP_BASE}")

    # Parar containers se solicitado
    if args.stop:
        print("\n⏹️  Parando containers...")
        subprocess.run(["docker", "stop"] + [c.name for c in client.containers.list()], check=False)

    backup_volumes(client)
    export_images(client)
    generate_compose(client)
    generate_restore_script()

    # Reiniciar containers se foram parados
    if args.stop:
        print("\n▶️  Reiniciando containers...")
        subprocess.run(["docker", "start"] + [c.name for c in client.containers.list(all=True)], check=False)

    if args.sync:
        sync_to_remote(args.sync, args.port)

    print("\n🎉 Backup completo!")


def cmd_restore(args):
    """Executa restore no servidor atual."""
    restore_script = BACKUP_BASE / "restore.sh"
    if not restore_script.exists():
        print("❌ restore.sh não encontrado. Execute backup primeiro.")
        sys.exit(1)

    subprocess.run(["bash", str(restore_script)], cwd=str(BACKUP_BASE), check=True)


def main():
    parser = argparse.ArgumentParser(description="Docker Backup & Migration Tool")
    sub = parser.add_subparsers(dest="command")

    # backup
    bp = sub.add_parser("backup", help="Backup volumes + imagens + compose")
    bp.add_argument("--sync", metavar="USER@HOST", help="Sincronizar via rsync para servidor remoto")
    bp.add_argument("--port", type=int, default=22, help="Porta SSH para rsync (default: 22)")
    bp.add_argument("--stop", action="store_true", help="Parar containers antes do backup (mais seguro para DBs)")

    # restore
    sub.add_parser("restore", help="Restaurar backup no servidor atual")

    args = parser.parse_args()

    if args.command == "backup":
        cmd_backup(args)
    elif args.command == "restore":
        cmd_restore(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
