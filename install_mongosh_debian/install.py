import subprocess

def run_command(command, success_message=None, error_message=None):
    """Executa um comando de shell e retorna a saída."""
    try:
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if success_message:
            print(success_message)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        if error_message:
            print(f"Erro: {error_message}\nDetalhes: {e.stderr.strip()}")
        else:
            print(f"Erro ao executar o comando '{' '.join(command)}': {e.stderr.strip()}")
        return None

# Passo 1: Adicionar a chave GPG do MongoDB
print("Adicionando a chave GPG do MongoDB...")
gpg_key_url = "https://www.mongodb.org/static/pgp/server-6.0.asc"
gpg_add_command = ["wget", "-qO", "/usr/share/keyrings/mongodb-archive-keyring.gpg", gpg_key_url]
run_command(
    gpg_add_command,
    success_message="Chave GPG adicionada com sucesso.",
    error_message="Falha ao adicionar a chave GPG. Verifique sua conexão com a internet e tente novamente."
)

# Passo 2: Adicionar o repositório do MongoDB
print("Adicionando o repositório do MongoDB...")
repo = "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg] https://repo.mongodb.org/apt/debian bullseye/mongodb-org/6.0 main"
add_repo_command = ["sudo", "bash", "-c", f'echo "{repo}" > /etc/apt/sources.list.d/mongodb-org-6.0.list']
run_command(
    add_repo_command,
    success_message="Repositório do MongoDB adicionado com sucesso.",
    error_message="Falha ao adicionar o repositório do MongoDB. Verifique as permissões e tente novamente."
)

# Passo 3: Atualizar o cache do APT
print("Atualizando o cache do APT...")
update_cache_command = ["sudo", "apt", "update"]
run_command(
    update_cache_command,
    success_message="Cache do APT atualizado com sucesso.",
    error_message="Falha ao atualizar o cache do APT. Verifique o repositório e sua conexão com a internet."
)

# Passo 4: Instalar o MongoDB Shell (mongosh)
print("Instalando o MongoDB Shell (mongosh)...")
install_mongosh_command = ["sudo", "apt", "install", "-y", "mongodb-mongosh"]
run_command(
    install_mongosh_command,
    success_message="MongoDB Shell instalado com sucesso.",
    error_message="Falha ao instalar o MongoDB Shell. Verifique os logs acima para mais detalhes."
)

# Passo 5: Verificar a instalação do mongosh
print("Verificando a instalação do MongoDB Shell...")
mongosh_version_command = ["mongosh", "--version"]
mongosh_version = run_command(
    mongosh_version_command,
    success_message="Verificação concluída.",
    error_message="Falha ao verificar a instalação do MongoDB Shell. Certifique-se de que o pacote foi instalado corretamente."
)
if mongosh_version:
    print(f"MongoDB Shell instalado com sucesso. Versão: {mongosh_version}")
else:
    print("A instalação do MongoDB Shell não foi concluída com sucesso. Verifique os passos anteriores.")
