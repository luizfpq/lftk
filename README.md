# LFTK - Linux Fine Tuner Kit

Kit de ferramentas para ajustes, automações e configurações em servidores e desktops Linux.

## Início rápido

```bash
git clone <repo-url> && cd lftk
./lftk.sh
```

## Convenções de nomenclatura

### Pastas

Formato: `<ação>_<alvo>[_<distro>]`

| Prefixo | Significado | Exemplo |
|---------|-------------|---------|
| `install_` | Instala software | `install_docker_debian/` |
| `setup_` | Configura algo existente | `setup_grub_savedefault/` |
| `backup_` | Backup ou migração | `backup_docker/` |
| `fix_` | Corrige problema específico | `fix_gtk_input/` |
| `generate_` | Gera artefatos ou dados | `generate_aliases/` |
| `import_` | Importa recurso externo | `import_gpg_key/` |

Quando o módulo é específico de uma distro, o sufixo indica: `_debian`, `_alpine`, etc.

Exceções aceitas:
- `firewall/` — agrupamento temático com múltiplas ações internas
- `docs/` — documentação e manuais

### Scripts

Dentro de cada pasta, o script principal recebe o nome da **ação** que executa:

| Padrão | Quando usar | Exemplo |
|--------|-------------|---------|
| `install.{py,sh}` | Script principal de instalação | `install_docker_alpine/install.sh` |
| `setup.{py,sh}` | Script principal de configuração | `setup_swap_vps/setup.py` |
| `fix.{py,sh}` | Script principal de correção | `fix_gtk_input/fix.py` |
| `generate.{py,sh}` | Script principal de geração | `generate_aliases/generate.py` |
| `migrate.py` | Migração/transferência | `backup_docker/migrate.py` |
| `<nome_descritivo>.{py,sh}` | Scripts auxiliares ou secundários | `backup_docker/backup_volumes.py` |

### Regras gerais

1. Tudo em `snake_case` — sem hífens, sem camelCase, sem maiúsculas
2. Shebang obrigatório: `#!/usr/bin/env python3` ou `#!/bin/bash` (ou `#!/bin/sh` para Alpine)
3. Um módulo = uma pasta = uma responsabilidade
4. `requirements.txt` na pasta quando houver dependências Python externas
5. `README.md` na pasta apenas quando necessário explicar uso complexo
6. Nomes curtos e diretos — evitar redundância com o nome da pasta

### Anti-padrões (não fazer)

```
❌ docker_backups/backup_docker_volumes.py    (redundante com pasta)
✅ backup_docker/backup_volumes.py            (pasta dá contexto)

❌ grub_savedefault/run.py                    (genérico demais)
✅ setup_grub_savedefault/setup.py            (ação clara)

❌ mongo_shell_debian/main.py                 (não diz o que faz)
✅ install_mongosh_debian/install.py          (ação + alvo)

❌ backup-containers.sh                       (hífen)
✅ export_containers.sh                       (snake_case + ação precisa)
```

## Estrutura

```
lftk/
├── lftk.sh                              # Menu interativo
├── setup_static_ip.py                   # IP estático (ironqui-*)
│
├── backup_docker/
│   ├── migrate.py                       # Backup + migração via rsync
│   ├── backup_volumes.py                # Backup de volumes
│   ├── generate_restore.py             # Gera docker-compose.restore.yml
│   └── requirements.txt
│
├── install_docker_debian/
│   ├── install.py                       # Instala Docker CE
│   ├── setup_memory.py                  # Otimiza memória (zram/zswap)
│   └── export_containers.sh            # Export/import containers
│
├── install_docker_alpine/
│   └── install.sh                       # Instala Docker + compose
│
├── firewall/
│   ├── ufw_apply_whitelist.py           # Whitelist exclusiva no UFW
│   ├── map_ports.py                     # Portas → processos (JSON)
│   ├── map_ports.sh                     # Portas → processos (detalhado)
│   ├── port_auditor.py                  # Auditoria com psutil
│   └── requirements.txt
│
├── setup_smb_shares/
│   └── setup.sh                         # Cria share Samba
│
├── setup_grub_savedefault/
│   └── setup.py                         # GRUB savedefault
│
├── setup_notebook_server/
│   ├── disable_suspend.py               # Desabilita suspend (tampa)
│   └── disable-lid-suspend.service
│
├── setup_swap_vps/
│   └── setup.py                         # Cria swapfile
│
├── setup_mount_softraid/
│   └── mount.py                         # Monta RAID dinâmico (ldmtool)
│
├── setup_fog_pxe/
│   └── prepare_iso.sh                   # Prepara ISO para PXE
│
├── install_nvidia/
│   ├── install.sh                       # NVIDIA stable
│   └── install_testing.sh              # NVIDIA testing
│
├── install_texlive/
│   └── install.sh                       # TeX Live completo
│
├── install_npm_alpine/
│   └── install.sh                       # Nginx Proxy Manager
│
├── install_mongosh_debian/
│   └── install.py                       # MongoDB Shell
│
├── import_gpg_key/
│   └── import.py                        # Importa chave GPG
│
├── fix_gtk_input/
│   └── fix.py                           # Fix GTK_IM_MODULE
│
├── generate_aliases/
│   └── generate.py                      # Gera aliases no bashrc
│
├── generate_mysql_users/
│   └── generate.py                      # Usuários MySQL em lote
│
└── docs/
    └── mdadm_raid1.md                   # Guia RAID1
```

## Módulos

### 🐳 Docker

| Script | Descrição |
|--------|-----------|
| `backup_docker/migrate.py` | Backup completo + migração via rsync |
| `backup_docker/backup_volumes.py` | Backup seguro de volumes |
| `backup_docker/generate_restore.py` | Gera `docker-compose.restore.yml` |
| `install_docker_debian/install.py` | Instala Docker CE no Debian |
| `install_docker_debian/setup_memory.py` | Otimiza memória para Docker |
| `install_docker_alpine/install.sh` | Instala Docker no Alpine |

#### Migração entre servidores

```bash
cd backup_docker
python3 migrate.py backup --stop --sync user@servidor-destino
# No destino:
python3 migrate.py restore
```

### 🌐 Rede & Firewall

| Script | Descrição |
|--------|-----------|
| `setup_static_ip.py` | IP estático baseado no hostname `ironqui-<N>` |
| `firewall/ufw_apply_whitelist.py` | Whitelist exclusiva de IPs+portas |
| `firewall/map_ports.py` | Portas abertas com PID e serviço (JSON) |
| `firewall/map_ports.sh` | Versão detalhada com systemd |
| `firewall/port_auditor.py` | Auditoria visual de portas |
| `setup_smb_shares/setup.sh` | Cria share Samba |

### ⚙️ Sistema & Hardware

| Script | Descrição |
|--------|-----------|
| `setup_grub_savedefault/setup.py` | GRUB savedefault para dual-boot |
| `setup_notebook_server/disable_suspend.py` | Desabilita suspend (tampa) |
| `setup_swap_vps/setup.py` | Cria swapfile em VPS |
| `setup_mount_softraid/mount.py` | Monta discos dinâmicos Windows |
| `install_nvidia/install.sh` | Drivers NVIDIA |
| `install_texlive/install.sh` | TeX Live completo |
| `install_npm_alpine/install.sh` | Nginx Proxy Manager no Alpine |

### 🔧 Utilitários

| Script | Descrição |
|--------|-----------|
| `import_gpg_key/import.py` | Importa chave GPG |
| `fix_gtk_input/fix.py` | Corrige input em webapps |
| `generate_aliases/generate.py` | Gera aliases no bashrc |
| `install_mongosh_debian/install.py` | Instala mongosh |
| `generate_mysql_users/generate.py` | Cria usuários MySQL em lote |
| `setup_fog_pxe/prepare_iso.sh` | Registra ISO para PXE |

## Dependências

```bash
pip install -r backup_docker/requirements.txt    # docker, pyyaml
pip install -r firewall/requirements.txt         # psutil
```

## ⚠️ Atenção

Scripts alteram configurações de sistema. Revise antes de executar em produção.

## Licença

GPL-3.0
