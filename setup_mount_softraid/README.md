#Adiciona o software raid feito pelo windows 

## Montagem Automática de RAID0 no Boot

Este script em Python automatiza o processo de montagem de um RAID0 no boot do sistema, seguindo as etapas descritas abaixo:

## Passos

1. **Instalação do ldmtool:**
   - O script instala o `ldmtool` utilizando o comando `sudo apt-get install ldmtool`.

2. **Criação do Serviço ldmtool:**
   - Cria um serviço chamado `ldmtool.service` em `/etc/systemd/system/`, configurando-o para montar o RAID0 no boot.

3. **Habilitação do Serviço:**
   - Usa `sudo systemctl enable ldmtool` para garantir que o serviço seja executado durante o boot.

4. **Obtenção do UUID do Volume:**
   - Utiliza `sudo blkid` para encontrar o UUID do volume necessário para montagem.

5. **Adição ao /etc/fstab:**
   - Adiciona uma linha ao arquivo `/etc/fstab` com o UUID encontrado, garantindo a montagem automática do volume no boot.

## Utilização

- Execute o script `montagem_raid0.py` com privilégios de administrador:

- Certifique-se de fazer backup de arquivos importantes antes de executar o script.
- É necessário modificar o arquivo `/etc/fstab`, então conhecimento prévio é recomendado.

**Nota:** Este script realiza modificações no sistema, então use com cuidado e compreensão dos efeitos no sistema de arquivos.
