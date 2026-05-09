import subprocess

def run_command(command):
    try:
        subprocess.run(command, shell=True, check=True)
        return True  # Sucesso
    except subprocess.CalledProcessError:
        return False  # Falha

# Desinstalar pacotes conflitantes
packages = ['docker.io', 'docker-doc', 'docker-compose', 'podman-docker', 'containerd', 'runc']
for pkg in packages:
    status = run_command(f'sudo apt-get remove {pkg}')
    print(f'Removed {pkg} successfully: {status}')

# Configurar repositório do Docker
commands = [
    'sudo apt-get update',
    'sudo apt-get install ca-certificates curl gnupg',
    'sudo install -m 0755 -d /etc/apt/keyrings',
    'curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg',
    'sudo chmod a+r /etc/apt/keyrings/docker.gpg',
    # Adicionar repositório ao Apt sources
    '''echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null''',
    'sudo apt-get update'
]

for cmd in commands:
    status = run_command(cmd)
    print(f'Command "{cmd}" executed successfully: {status}')

# Instalar pacotes do Docker
docker_install = 'sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'
status = run_command(docker_install)
print(f'Docker packages installed: {status}')

# Verificar a instalação executando o hello-world
hello_world = 'sudo docker run hello-world'
status = run_command(hello_world)
print(f'Hello-world image ran successfully: {status}')

# Criar grupo docker e adicionar usuário
commands = [
    'sudo groupadd docker',
    f'sudo usermod -aG docker {subprocess.run("echo $USER", shell=True, check=True, capture_output=True, text=True).stdout.strip()}'
]

for cmd in commands:
    status = run_command(cmd)
    print(f'Command "{cmd}" executed successfully: {status}')

# Reconhecer alterações nos grupos
newgrp_docker = 'newgrp docker'
status = run_command(newgrp_docker)
print(f'Changes to groups activated: {status}')
print(f'Instalation terminated, start working...')