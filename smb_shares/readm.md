# 🖥️ `sharer.sh` — Script Automático de Configuração de Compartilhamento Samba no Debian

Um script Bash simples e seguro para configurar rapidamente um compartilhamento Samba em sistemas Debian/Ubuntu, com base em um único parâmetro: `usuário@caminho`.

Ideal para desenvolvedores, administradores de sistemas ou estudantes que precisam de compartilhamento de arquivos entre host e VM (QEMU/KVM, VirtualBox, etc.) sem precisar editar arquivos manualmente.

---

## ✅ Recursos

- Cria o usuário do sistema (se não existir)
- Cria o diretório de compartilhamento com permissões corretas
- Instala o Samba automaticamente (se necessário)
- Adiciona o usuário ao Samba com senha segura
- Configura o compartilhamento no `/etc/samba/smb.conf`
- Reinicia os serviços `smbd` e `nmbd`
- Evita duplicações no arquivo de configuração

---

## 🚀 Como Usar

### 1. Pré-requisitos

- Sistema baseado em Debian/Ubuntu (testado no Debian 12)
- Acesso root (`sudo`)

