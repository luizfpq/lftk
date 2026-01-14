import docker
import os
import yaml
from pathlib import Path

client = docker.from_env()

BASE_DIR = Path.home() / "docker_backups"
BASE_DIR.mkdir(parents=True, exist_ok=True)

compose = {
    "version": "3.9",
    "services": {}
}

def safe(name: str) -> str:
    return name.replace("/", "_").replace(":", "_")

containers = client.containers.list(all=True)

for c in containers:
    inspect = client.api.inspect_container(c.id)

    image = inspect["Config"]["Image"]
    container_name = inspect["Name"].lstrip("/")
    image_dir = safe(image)

    mounts = inspect.get("Mounts", [])
    ports = inspect["HostConfig"].get("PortBindings", {})
    envs = inspect["Config"].get("Env", [])

    if not mounts:
        continue

    service = {
        "image": image,
        "container_name": container_name,
        "restart": "unless-stopped",
    }

    # Volumes
    volumes = []
    for m in mounts:
        src = f"./{image_dir}/data/{safe(m['Destination'].strip('/'))}"
        volumes.append(f"{src}:{m['Destination']}")

    if volumes:
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

    compose["services"][container_name] = service

# Grava docker-compose.restore.yml
compose_file = BASE_DIR / "docker-compose.restore.yml"
with open(compose_file, "w") as f:
    yaml.dump(compose, f, sort_keys=False)

print(f"\n✅ docker-compose de restore gerado em:")
print(f"👉 {compose_file}")
