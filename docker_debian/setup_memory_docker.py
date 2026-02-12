#!/usr/bin/env python3
import os
import subprocess
import shutil

def run(cmd):
    print(f"▶ {cmd}")
    subprocess.run(cmd, shell=True, check=True)

def ensure_root():
    if os.geteuid() != 0:
        print("❌ Execute como root (sudo).")
        exit(1)

def install_packages():
    run("apt update")
    run("apt install -y zram-tools docker.io docker-cli")

def configure_zram():
    path = "/etc/default/zramswap"
    content = """# ZRAM otimizado
PERCENT=50
PRIORITY=100
"""
    with open(path, "w") as f:
        f.write(content)

    run("systemctl enable zramswap --now")

def configure_sysctl():
    path = "/etc/sysctl.d/99-memory-tuning.conf"
    content = """# Memória otimizada para host Docker pequeno
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.overcommit_memory=1
kernel.panic_on_oom=0
"""
    with open(path, "w") as f:
        f.write(content)

    run(f"sysctl -p {path}")

def configure_zswap():
    grub = "/etc/default/grub"
    backup = grub + ".bak"

    if not os.path.exists(backup):
        shutil.copy(grub, backup)

    with open(grub, "r") as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        if line.startswith("GRUB_CMDLINE_LINUX_DEFAULT"):
            if "zswap.enabled" not in line:
                line = line.strip().rstrip('"') + \
                    " zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=20\"\n"
        new_lines.append(line)

    with open(grub, "w") as f:
        f.writelines(new_lines)

    run("update-grub")

def configure_swapfile():
    swapfile = "/swapfile"
    if not os.path.exists(swapfile):
        run("fallocate -l 8G /swapfile")
        run("chmod 600 /swapfile")
        run("mkswap /swapfile")
        run("swapon /swapfile")

        with open("/etc/fstab", "a") as f:
            f.write("/swapfile none swap sw 0 0\n")

def configure_docker():
    os.makedirs("/etc/docker", exist_ok=True)
    path = "/etc/docker/daemon.json"

    content = """{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "oom-score-adjust": -500,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
"""
    with open(path, "w") as f:
        f.write(content)

    run("systemctl restart docker")

def create_container_profile():
    path = "/usr/local/bin/docker-critical-run.sh"
    content = """#!/bin/bash
docker run -d \\
  --name "$1" \\
  --memory="256m" \\
  --memory-swap="512m" \\
  --oom-score-adj=-900 \\
  --restart unless-stopped \\
  "$@"
"""
    with open(path, "w") as f:
        f.write(content)

    run(f"chmod +x {path}")

def main():
    ensure_root()
    install_packages()
    configure_zram()
    configure_sysctl()
    configure_zswap()
    configure_swapfile()
    configure_docker()
    create_container_profile()

    print("""
✅ CONFIGURAÇÃO FINALIZADA

⚠️ Reinicie o sistema para ativar o ZSWAP:
   sudo reboot

📌 Para rodar containers críticos:
   docker-critical-run.sh nome imagem:tag

📊 Verificações:
   free -h
   swapon
   docker stats
""")

if __name__ == "__main__":
    main()
