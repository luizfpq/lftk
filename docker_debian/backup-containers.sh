#!/bin/bash

# Verifica se foi fornecido um argumento
if [ -z "$1" ]; then
    echo "Uso: $0 [exportar|importar]"
    exit 1
fi

# Exportar containers
if [ "$1" == "exportar" ]; then
    # Obtém a lista de nomes de todos os containers em execução
    container_names=$(docker ps --format '{{.Names}}')

    # Loop sobre cada nome de container
    for container_name in $container_names
    do
        # Gera um nome único para a nova imagem em minúsculas
        nova_imagem="nova-imagem-$(echo $container_name | tr '[:upper:]' '[:lower:]')"

        # Cria uma nova imagem a partir do container
        docker commit $container_name $nova_imagem
        docker save $nova_imagem> ./$nova_imagem.tar

        # Inspect do container para obter as configurações
        docker inspect $container_name > "./container-$(echo $container_name | tr '[:upper:]' '[:lower:]')-inspect.json"

        echo "Container $container_name exportado como $nova_imagem"
    done

# Importar containers
elif [ "$1" == "importar" ]; then
    # Obtém a lista de arquivos .tar e inspeciona arquivos no diretório .
    arquivos_inspect=$(ls ./container-*-inspect.json)

    # Loop sobre cada arquivo de inspeção
    for arquivo_inspect in $arquivos_inspect
    do
        # Obtém o nome do container a partir do nome do arquivo
        container_name=$(basename $arquivo_inspect | cut -d'-' -f2 | cut -d'.' -f1)

        # Gera um Dockerfile a partir das configurações do container
        docker inspect --format="{{.Config.Cmd}} {{.Config.Env}} {{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}" $container_name > "./Dockerfile-$(echo $container_name | tr '[:upper:]' '[:lower:]')"

        echo "Dockerfile gerado para o container $container_name"

        docker load -i "nova-imagem-$container_name.tar"
        docker create --name $container_name -it nova-imagem-$container_name

        docker start $container_name


    done

else
    echo "Opção inválida. Use $0 [exportar|importar]"
    exit 1
fi
