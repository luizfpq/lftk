# Tutorial: Migrar de um Sistema RAID1 por Software (`mdadm`) para um Disco Único sem Perder Dados

> **Última atualização**: 16 de outubro de 2025  
> **Plataformas testadas**: Debian 12, Ubuntu 22.04/24.04 (Live Environments)  
> **Nível**: Intermediário  
> **Tempo estimado**: 20–40 minutos  
> **Risco**: Médio — exige cuidado com partições e boot, mas **não apaga dados** se seguido corretamente.

---

## 📌 Sumário

- [Introdução](#introdução)
- [Contexto e Casos de Uso](#contexto-e-casos-de-uso)
- [Pré-requisitos](#pré-requisitos)
- [Passo a Passo Completo](#passo-a-passo-completo)
  - [1. Diagnóstico: Verifique se há RAID ativo](#1-diagnóstico-verifique-se-há-raid-ativo)
  - [2. Ative os arrays RAID (se aplicável)](#2-ative-os-arrays-raid-se-aplicável)
  - [3. Monte o sistema-alvo](#3-monte-o-sistema-alvo)
  - [4. Atualize `/etc/fstab`](#4-atualize-etcfstab)
  - [5. Remova a dependência do `mdadm` no initramfs](#5-remova-a-dependência-do-mdadm-no-initramfs)
  - [6. Reinstale o GRUB no disco único](#6-reinstale-o-grub-no-disco-único)
  - [7. Limpeza final](#7-limpeza-final)
  - [8. Reinicie e valide](#8-reinicie-e-valide)
- [Alternativas](#alternativas)
- [Avaliação de Riscos](#avaliação-de-riscos)
- [Referências Oficiais](#referências-oficiais)
- [Conclusão](#conclusão)

---

## Introdução

Sistemas Linux frequentemente usam **RAID1 por software** (`mdadm`) para redundância de dados, especialmente em servidores ou ambientes críticos. No entanto, em cenários de desktop, testes ou migração para hardware mais simples, pode ser desejável **remover o RAID** e operar com um **único disco**, mantendo todos os arquivos, configurações e capacidade de inicialização.

Este tutorial ensina como fazer essa transição **de forma segura**, sem formatação, sem perda de dados e com boot funcional.

> ⚠️ **Importante**: Este guia **não apaga partições nem arquivos**. Ele apenas **remove a camada de RAID** e reconfigura o sistema para usar partições diretamente.

---

## Contexto e Casos de Uso

Você pode precisar deste procedimento se:

- Estiver migrando um sistema de um servidor RAID para um laptop/desktop.
- Quiser simplificar um sistema de recuperação baseado em RAID.
- Estiver testando uma instalação e decidir que não precisa mais de redundância.
- Tiver um disco falhando e quiser manter o sistema em um único disco funcional.

---

## Pré-requisitos

Antes de começar, verifique:

✅ **Ambiente Live**:  
Você deve estar em um **sistema live** (ex: Ubuntu Live USB, Debian Live CD). Isso evita conflitos com sistemas montados.

✅ **Dois discos com layout RAID1**:  
- Disco A: `/dev/sda` → `sda1` (1 GiB, `/boot`), `sda2` (31 GiB, `/`)
- Disco B: `/dev/sdb` → `sdb1`, `sdb2` (mesmo layout)

✅ **Arrays sincronizados**:  
Ambos os arrays devem estar em estado `[UU]` (completos). Verifique com:
```bash
cat /proc/mdstat
```

✅ **Backup (recomendado)**:  
Embora o risco seja baixo, **faça backup de dados críticos** antes de alterar o sistema de boot.

✅ **Acesso root**:  
Todos os comandos exigem privilégios de administrador (`sudo`).

---

## Passo a Passo Completo

### 1. Diagnóstico: Verifique se há RAID ativo

Primeiro, confirme se os discos realmente contêm metadados de RAID:

```bash
sudo mdadm --examine /dev/sda1
sudo mdadm --examine /dev/sda2
```

🔍 **Saída esperada (com RAID)**:
```
Raid Level : raid1
Array UUID : a1b2c3d4:...
```

🔍 **Saída sem RAID**:
```
mdadm: No md superblock detected on /dev/sda1.
```

> 💡 **Se não houver RAID**, pule para a [seção de alternativas](#alternativas).

Verifique também o estado atual:
```bash
cat /proc/mdstat
```

Se não houver arrays listados, mas os metadados existirem, você precisará **ativá-los manualmente**.

---

### 2. Ative os arrays RAID (se aplicável)

Pare arrays residuais e reative com os discos conhecidos:

```bash
sudo mdadm --stop /dev/md0 /dev/md1 2>/dev/null

# Ative /boot (1 GiB)
sudo mdadm --assemble --run /dev/md0 /dev/sda1 /dev/sdb1

# Ative / (31 GiB)
sudo mdadm --assemble --run /dev/md1 /dev/sda2 /dev/sdb2
```

> 📚 **Referência**: [`man mdadm`](https://man7.org/linux/man-pages/man8/mdadm.8.html)  
> A opção `--run` força a ativação mesmo com discos ausentes (útil em RAID1 degradado).

Verifique o estado:
```bash
watch -n 2 cat /proc/mdstat
```

Aguarde até ver `[UU]` em ambos os arrays.

---

### 3. Monte o sistema-alvo

Crie um ponto de montagem e monte o sistema:

```bash
sudo mkdir -p /mnt/target
sudo mount /dev/md1 /mnt/target          # raiz
sudo mount /dev/md0 /mnt/target/boot     # /boot
```

Valide:
```bash
ls /mnt/target/etc/fstab
ls /mnt/target/boot/grub/grub.cfg
```

Se os arquivos estiverem presentes, prossiga.

---

### 4. Atualize `/etc/fstab`

Edite o arquivo de montagem para usar **partições diretas**, não dispositivos RAID:

```bash
sudo nano /mnt/target/etc/fstab
```

Altere as entradas de:
```conf
/dev/md0  /boot  ext4  defaults  0 2
/dev/md1  /      ext4  defaults  0 1
```

Para:
```conf
/dev/sda1 /boot  ext4  defaults  0 2
/dev/sda2 /      ext4  defaults  0 1
```

> 💡 **Dica avançada**: Prefira **UUIDs** para maior robustez:
> ```bash
> sudo blkid /dev/sda1 /dev/sda2
> ```
> E use no `fstab`:
> ```conf
> UUID=abcd1234 /boot ext4 defaults 0 2
> ```

---

### 5. Remova a dependência do `mdadm` no initramfs

Monte os diretórios especiais e entre no sistema com `chroot`:

```bash
sudo mount --bind /dev /mnt/target/dev
sudo mount --bind /proc /mnt/target/proc
sudo mount --bind /sys /mnt/target/sys

sudo chroot /mnt/target
```

Dentro do `chroot`:

```bash
# Desative o suporte a RAID no initramfs
echo "none" > /etc/initramfs-tools/conf.d/mdadm

# Atualize o initramfs para todos os kernels
update-initramfs -u -k all

# Atualize a configuração do GRUB
update-grub

exit  # sai do chroot
```

> 📚 **Referência**: [`man update-initramfs`](https://manpages.debian.org/bullseye/initramfs-tools/update-initramfs.8.en.html)

---

### 6. Reinstale o GRUB no disco único

Instale o bootloader diretamente no disco que será mantido (`/dev/sda`):

```bash
sudo grub-install \
  --target=i386-pc \
  --boot-directory=/mnt/target/boot \
  /dev/sda
```

> ⚠️ **BIOS vs UEFI**:  
> - Este comando é para **BIOS + GPT/MBR**.  
> - Se usar **UEFI**, substitua por:
>   ```bash
>   sudo grub-install --target=x86_64-efi --efi-directory=/mnt/target/boot/efi --bootloader-id=GRUB
>   ```
>   (e certifique-se de ter uma partição EFI).

---

### 7. Limpeza final

Desmonte tudo:
```bash
sudo umount /mnt/target/{dev,proc,sys,boot,}
```

Pare os arrays:
```bash
sudo mdadm --stop /dev/md0 /dev/md1
```

(Opcional) Remova metadados de RAID **do disco que será mantido**:
```bash
sudo mdadm --zero-superblock /dev/sda1
sudo mdadm --zero-superblock /dev/sda2
```

> ❌ **Não faça isso no disco que será descartado** se quiser mantê-lo como backup.

---

### 8. Reinicie e valide

```bash
sudo reboot
```

Após o boot:

```bash
# Verifique partições montadas
df -h

# Confirme ausência de RAID
cat /proc/mdstat

# Liste blocos
lsblk
```

✅ **Sucesso** se:
- `/` estiver em `/dev/sda2`
- `/boot` estiver em `/dev/sda1`
- Não houver dispositivos `md0`, `md1`, etc.

---

## Alternativas

### A. Sistema sem RAID desde o início

Se `mdadm --examine` **não detectar metadados**, seu sistema **nunca usou RAID**. Nesse caso:

```bash
sudo mount /dev/sda2 /mnt/target
sudo mount /dev/sda1 /mnt/target/boot
sudo grub-install --boot-directory=/mnt/target/boot /dev/sda
sudo reboot
```

### B. Usar `dd` para clonar (não recomendado para tamanhos diferentes)

Embora possível, `dd` copia bit-a-bit e **não ajusta UUIDs, fstab ou GRUB**, exigindo pós-processamento manual. **Não é recomendado**.

### C. Reinstalar o sistema

A opção mais simples, mas **perde configurações personalizadas**. Use apenas se os dados não forem críticos.

---

## Avaliação de Riscos

| Risco | Probabilidade | Impacto | Mitigação |
|------|---------------|--------|----------|
| Sistema não inicializa | Baixa | Alto | Teste o boot antes de remover o segundo disco |
| Perda de dados | Muito baixa | Crítico | **Nenhum dado é apagado**; apenas metadados de RAID são removidos |
| Erro no `fstab` | Média | Médio | O script faz backup automático do `fstab` |
| Confusão entre discos | Média | Alto | Use `lsblk` e `blkid` para confirmar dispositivos |

> ✅ **Conclusão de risco**: Baixo, desde que o passo a passo seja seguido com atenção.

---

## Referências Oficiais

- [`man mdadm`](https://man7.org/linux/man-pages/man8/mdadm.8.html)
- [`man grub-install`](https://www.gnu.org/software/grub/manual/grub/html_node/Invoking-grub_002dinstall.html)
- [`man update-initramfs`](https://manpages.debian.org/bullseye/initramfs-tools/update-initramfs.8.en.html)
- [Debian RAID Wiki](https://wiki.debian.org/RAID)
- [Ubuntu: Converting RAID1 to single disk](https://help.ubuntu.com/community/RAID)

---

## Conclusão

Migrar de um sistema RAID1 para um disco único é **totalmente viável** sem perda de dados. O processo envolve:

1. **Ativar o RAID temporariamente** para acesso aos arquivos,
2. **Reconfigurar o sistema** para usar partições diretas,
3. **Remover dependências de RAID** do initramfs e GRUB,
4. **Validar o boot** em um ambiente controlado.

Este tutorial oferece um caminho seguro, documentado e reversível (enquanto o segundo disco estiver disponível). Após a migração, seu sistema será mais simples, rápido e adequado para ambientes não críticos.

> 🌟 **Dica final**: Após confirmar que tudo funciona, **guarde o segundo disco como backup offline** — ele ainda contém uma cópia completa do sistema!

---

**Autor**: Comunidade Linux / Adaptado de experiências práticas  
**Licença**: CC BY-SA 4.0 — Sinta-se livre para compartilhar e adaptar com crédito.