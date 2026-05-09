import os
import platform
import subprocess

def is_manjaro():
    with open('/etc/os-release') as f:
        return 'Manjaro' in f.read()

def is_ubuntu():
    with open('/etc/os-release') as f:
        return 'Ubuntu' in f.read()

def is_debian():
    with open('/etc/os-release') as f:
        return 'Debian' in f.read()

def add_gtk_im_module():
    if is_manjaro():
        with open('/etc/environment', 'a') as f:
            f.write('\nGTK_IM_MODULE=xim\n')
        print("Adicionado 'GTK_IM_MODULE=xim' ao /etc/environment no Manjaro.")

    elif is_ubuntu():
        try:
            subprocess.run(['im-config', '-n', 'xim'], check=True)
            print("Executado 'im-config -n xim' no Ubuntu.")
        except subprocess.CalledProcessError as e:
            print(f"Erro ao executar o comando: {e}")

    elif is_debian():
        # Adiciona GTK_IM_MODULE=xim ao arquivo ~/.profile ou ~/.bashrc
        home_profile = os.path.expanduser('~/.profile')
        with open(home_profile, 'a') as f:
            f.write('\nexport GTK_IM_MODULE=xim\n')
        print("Adicionado 'export GTK_IM_MODULE=xim' ao ~/.profile no Debian.")

    else:
        print("Sistema não suportado. Este script é destinado apenas ao Manjaro, Ubuntu ou Debian.")

if __name__ == '__main__':
    add_gtk_im_module()
