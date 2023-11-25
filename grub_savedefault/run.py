import shutil
import os
import subprocess

def fazer_backup_arquivo(caminho_arquivo):
    pasta_arquivo, nome_arquivo = os.path.split(caminho_arquivo)
    nome_arquivo_backup = nome_arquivo + '.saved'
    caminho_backup = os.path.join(pasta_arquivo, nome_arquivo_backup)
    shutil.copyfile(caminho_arquivo, caminho_backup)

def alterar_arquivo_grub(caminho_arquivo):
    fazer_backup_arquivo(caminho_arquivo)

    linhas = []
    with open(caminho_arquivo, 'r') as arquivo:
        linhas = arquivo.readlines()

    alterou_grub_default = False
    adicionou_save_default = False
    alterou_os_prober = False

    for i, linha in enumerate(linhas):
        if linha.startswith('GRUB_DEFAULT='):
            linhas[i] = 'GRUB_DEFAULT=SAVED\n'
            alterou_grub_default = True
            if i + 1 < len(linhas) and not linhas[i + 1].startswith('#GRUB_SAVEDEFAULT='):
                linhas.insert(i + 1, 'GRUB_SAVEDEFAULT=true\n')
                adicionou_save_default = True
        elif linha.startswith('GRUB_DISABLE_OS_PROBER='):
            linhas[i] = 'GRUB_DISABLE_OS_PROBER=false\n'
            alterou_os_prober = True
    
    if not alterou_grub_default:
        linhas.append('GRUB_DEFAULT=SAVED\n')
    if not adicionou_save_default:
        linhas.append('GRUB_SAVEDEFAULT=true\n')
    if not alterou_os_prober:
        linhas.append('GRUB_DISABLE_OS_PROBER=false\n')
    
    with open(caminho_arquivo, 'w') as arquivo:
        arquivo.writelines(linhas)

    subprocess.run(['sudo', 'update-grub'])

caminho_grub = '/etc/default/grub'
alterar_arquivo_grub(caminho_grub)
