import subprocess
import sys

def import_gpg_key(gpg_key: str):
    try:
        # Comando a ser executado
        command = [
            "gpg",
            "--keyserver", "pgp.mit.edu",
            "--recv-keys", gpg_key
        ]

        # Executa o comando e captura a saída
        result = subprocess.run(command, check=True, text=True, capture_output=True)

        # Se o comando for bem-sucedido
        print(f"Chave GPG {gpg_key} importada com sucesso!\nSaída:\n{result.stdout}")

    except subprocess.CalledProcessError as e:
        # Tratamento de erro
        print(f"Erro ao importar a chave GPG {gpg_key}.\nMensagem de erro:\n{e.stderr}")
    except Exception as e:
        # Tratamento de erros inesperados
        print(f"Ocorreu um erro inesperado: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python script.py <GPG_KEY>")
        sys.exit(1)

    gpg_key = sys.argv[1]

    # Validação básica da chave GPG
    if not gpg_key.isalnum():
        print("Erro: A chave GPG deve ser um valor hexadecimal de 8 caracteres.")
        sys.exit(1)

    import_gpg_key(gpg_key)
