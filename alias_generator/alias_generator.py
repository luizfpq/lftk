def create_aliases(commands, alias_file_path):
    """
    Create aliases for given commands in a specified file.

    Args:
    commands (dict): A dictionary where keys are alias names and values are commands.
    alias_file_path (str): Path to the file where aliases will be written.
    """
    with open(alias_file_path, 'a') as alias_file:
        for alias, command in commands.items():
            alias_file.write(f"alias {alias}='{command}'\n")

# Exemplo de uso
if __name__ == "__main__":
    # Lista de comandos e seus aliases
    commands = {
        "ls": "ls -la",
        "grep": "grep --color=auto",
        "ll": "ls -l",
        "add-key": "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys "
        # Adicione mais comandos e aliases conforme necessário
    }

    # Caminho para o arquivo onde os aliases serão salvos
    alias_file_path = "/caminho/para/seu/arquivo/.bashrc"

    # Chamada da função para criar os aliases
    create_aliases(commands, alias_file_path)

    print("Aliases criados com sucesso!")
