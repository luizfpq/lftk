import csv
import mysql.connector

# Função para criar as bases de dados e conceder permissões
def criar_bases_dados(nome):
    # Conexão com o MySQL
    conexao = mysql.connector.connect(
        host="seu_host",
        user="seu_usuario",
        password="sua_senha",
        database="seu_banco_de_dados"
    )
    cursor = conexao.cursor()

    # Nome das bases de dados
    nome_default = f"{nome}_default"
    nome_backup = f"{nome}_backup"

    # Criar bases de dados
    cursor.execute(f"CREATE DATABASE {nome_default}")
    cursor.execute(f"CREATE DATABASE {nome_backup}")

    # Conceder permissões
    cursor.execute(f"GRANT ALL PRIVILEGES ON {nome_default}.* TO '{nome}'@'%'")
    cursor.execute(f"GRANT SELECT, BACKUP ON {nome_backup}.* TO '{nome}'@'%'")

    # Fechar conexão
    conexao.close()

# Ler o arquivo CSV
def ler_csv(nome_arquivo):
    with open(nome_arquivo, 'r') as arquivo:
        leitor = csv.reader(arquivo)
        for linha in leitor:
            nome = linha[0].strip()  # assumindo que o nome está na primeira coluna
            criar_bases_dados(nome)

# Executar o script
if __name__ == "__main__":
    arquivo_csv = "nomes.csv"  # nome do seu arquivo CSV
    ler_csv(arquivo_csv)
