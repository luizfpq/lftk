import csv
import mysql.connector
import random
import string

# Função para criar as bases de dados e conceder permissões
def criar_bases_dados(nome, senha):
    # Conexão com o MySQL
    conexao = mysql.connector.connect(
        host="",
        user="",
        password="",
        database=""
    )
    cursor = conexao.cursor()

    # Nome das bases de dados
    nome_default = f"{nome}_default"
    nome_backup = f"{nome}_backup"

    # Tentar criar usuário com a senha gerada
    try:
        cursor.execute(f"""CREATE USER '{nome}'@'%' IDENTIFIED BY '{senha.replace("'", "''")}'""")
        # Criar bases de dados
        cursor.execute(f"CREATE DATABASE {nome_default}")
        cursor.execute(f"CREATE DATABASE {nome_backup}")
        # Conceder permissões
        cursor.execute(f"GRANT ALL PRIVILEGES ON {nome_default}.* TO '{nome}'@'%'")
        cursor.execute(f"GRANT SELECT ON {nome_backup}.* TO '{nome}'@'%'")
    except mysql.connector.Error as err:
        print(f"Erro ao criar usuário '{nome}': {err}")
        return

    # Fechar conexão
    conexao.close()

# Função para gerar senha automaticamente
# Função para gerar senha automaticamente
def gerar_senha():
    caracteres = string.ascii_lowercase + string.digits
    senha = ''.join(random.choice(caracteres) for _ in range(12)) + random.choice(string.ascii_uppercase) + '@'
    senha = ''.join(random.sample(senha, len(senha)))
    return senha


# Ler o arquivo CSV
def ler_csv(nome_arquivo):
    with open(nome_arquivo, 'r') as arquivo:
        leitor = csv.reader(arquivo)
        for linha in leitor:
            nome = linha[0].strip()  # assumindo que o nome está na primeira coluna
            senha = gerar_senha()
            criar_bases_dados(nome, senha)
            print(f"Usuário '{nome}' criado com senha '{senha}'.")

# Executar o script
if __name__ == "__main__":
    arquivo_csv = "nomes.csv"  # nome do seu arquivo CSV
    ler_csv(arquivo_csv)
