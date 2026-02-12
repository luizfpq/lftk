import docker
import os
import shutil
import tempfile
from pathlib import Path
from typing import Optional

client = docker.from_env()

BACKUP_BASE = Path.home() / "docker_backups"
BACKUP_BASE.mkdir(parents=True, exist_ok=True)

def safe_name(name: str) -> str:
    """Sanitiza nome para uso em caminhos de arquivo."""
    return name.replace("/", "_").replace(":", "_")

def backup_volume_safely(source: str, target_dir: Path) -> bool:
    """
    Faz backup de forma segura usando diretório temporário.
    Remove backup antigo apenas se novo backup foi bem-sucedido.
    """
    if not source:
        print(f"  ⚠️  Source vazio")
        return False
    
    if not os.path.exists(source):
        print(f"  ⚠️  Source não existe: {source}")
        return False
    
    if not os.path.isdir(source):
        print(f"  ⚠️  Source não é um diretório: {source}")
        return False
    
    try:
        # Cria backup em diretório temporário primeiro
        with tempfile.TemporaryDirectory(dir=target_dir.parent) as temp_dir:
            temp_backup = Path(temp_dir) / target_dir.name
            shutil.copytree(source, temp_backup, symlinks=True)
            
            # Remove backup antigo apenas se novo backup foi bem-sucedido
            if target_dir.exists():
                shutil.rmtree(target_dir)
            
            # Move backup temporário para local final
            shutil.move(str(temp_backup), str(target_dir))
        return True
    except PermissionError as e:
        print(f"  ❌ Erro de permissão ao fazer backup: {e}")
        return False
    except shutil.Error as e:
        print(f"  ❌ Erro ao copiar arquivos: {e}")
        return False
    except Exception as e:
        print(f"  ❌ Erro inesperado ao fazer backup: {e}")
        return False

# Validação inicial do Docker
try:
    client.ping()
except docker.errors.DockerException as e:
    print(f"❌ Erro ao conectar ao Docker: {e}")
    print("   Verifique se o Docker está rodando e se você tem permissões adequadas.")
    exit(1)
except Exception as e:
    print(f"❌ Erro inesperado ao conectar ao Docker: {e}")
    exit(1)

# Verifica permissões no diretório de backup
if not os.access(BACKUP_BASE, os.W_OK):
    print(f"❌ Sem permissão de escrita no diretório: {BACKUP_BASE}")
    exit(1)

containers = client.containers.list(all=True)

if not containers:
    print("⚠️  Nenhum container encontrado.")
    exit(0)

print(f"🔍 Encontrados {len(containers)} container(s)")
print(f"📁 Diretório de backup: {BACKUP_BASE}\n")

backup_count = 0
error_count = 0
skipped_count = 0

for container in containers:
    try:
        # Obter nome da imagem de forma segura
        image_tags = container.image.tags if container.image.tags else []
        image_name = safe_name(image_tags[0] if image_tags else container.image.short_id)
        container_name = container.name

        inspect = client.api.inspect_container(container.id)
        mounts = inspect.get("Mounts", [])

        if not mounts:
            skipped_count += 1
            continue

        container_backup_dir = BACKUP_BASE / image_name / "data"
        container_backup_dir.mkdir(parents=True, exist_ok=True)

        print(f"\n📦 Container: {container_name}")
        print(f"🖼️  Imagem: {image_name}")

        for mount in mounts:
            source = mount.get("Source")
            destination = mount.get("Destination")
            mount_type = mount.get("Type", "unknown")

            if not source:
                print(f"  ⚠️  Mount sem source: {destination}")
                error_count += 1
                continue

            target_dir = container_backup_dir / safe_name(destination.strip("/"))

            print(f"  ↳ Backup volume ({mount_type}): {destination}")

            if backup_volume_safely(source, target_dir):
                backup_count += 1
                print(f"     ✅ Backup concluído")
            else:
                error_count += 1

    except docker.errors.NotFound:
        print(f"\n⚠️  Container {container.name} não encontrado (pode ter sido removido)")
        error_count += 1
        continue
    except Exception as e:
        print(f"\n❌ Erro ao processar container {container.name}: {e}")
        error_count += 1
        continue

print(f"\n{'='*50}")
print(f"✅ Backup finalizado!")
print(f"   📊 Volumes com backup: {backup_count}")
print(f"   ⚠️  Erros: {error_count}")
print(f"   ⏭️  Containers sem volumes: {skipped_count}")
print(f"{'='*50}")