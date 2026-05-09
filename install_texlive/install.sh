#!/bin/bash

set -e  # Aborta em caso de erro

echo "🚀 Iniciando instalação completa do TeX Live 2025..."

# 1. Pergunta se deseja remover instalações antigas via apt
read -p "Deseja remover pacotes texlive antigos instalados via apt? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo "Removendo instalações antigas do TeX Live..."
    sudo apt remove --purge -y texlive* > /dev/null 2>&1 || true
    sudo apt autoremove -y > /dev/null 2>&1 || true
fi

# 2. Instalar dependências mínimas
echo "Instalando dependências..."
sudo apt update
sudo apt install -y perl wget xzdec

# 3. Criar diretório temporário e baixar instalador
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
echo "Baixando instalador do TeX Live..."
wget -q --show-progress https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
tar -xzf install-tl-unx.tar.gz
cd install-tl-*/

# 4. Preparar arquivo de configuração para instalação completa (sem interação)
cat > texlive.profile <<EOF
selected_scheme full
TEXDIR /usr/local/texlive/2025
TEXMFCONFIG ~/.texlive2025/texmf-config
TEXMFHOME ~/texmf
TEXMFLOCAL /usr/local/texlive/texmf-local
TEXMFSYSCONFIG /usr/local/texlive/2025/texmf-config
TEXMFSYSVAR /usr/local/texlive/2025/texmf-var
TEXMFVAR ~/.texlive2025/texmf-var
binary_x86_64-linux 1
instopt_adjustpath 0
instopt_adjustrepo 1
instopt_letter 1
option_doc 1
option_src 1
EOF

# 5. Executar instalação silenciosa
echo "Iniciando instalação completa do TeX Live (pode levar 1-2 horas)..."
sudo ./install-tl --profile=texlive.profile

# 6. Adicionar ao PATH no ~/.bashrc
echo "Configurando PATH..."
LINE='export PATH="/usr/local/texlive/2025/bin/x86_64-linux:$PATH"'
if ! grep -qF "$LINE" ~/.bashrc; then
    echo "$LINE" >> ~/.bashrc
fi

# 7. Recarregar o PATH no shell atual
export PATH="/usr/local/texlive/2025/bin/x86_64-linux:$PATH"

# 8. Verificação final
echo "Verificando instalação..."
pdflatex --version
tlmgr --version

echo "✅ Instalação do TeX Live completa concluída!"
echo "💡 Execute 'source ~/.bashrc' ou reinicie o terminal para garantir o PATH."