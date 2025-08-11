#!/bin/bash

# 🚀 Script para executar o File Cloud Example
# Este script automatiza a execução do servidor e app de exemplo

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌟 File Cloud Example - Script de Execução${NC}"
echo "=================================================="

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar dependências
echo -e "${YELLOW}🔍 Verificando dependências...${NC}"

if ! command_exists dart; then
    echo -e "${RED}❌ Dart SDK não encontrado. Instale: https://dart.dev/get-dart${NC}"
    exit 1
fi

if ! command_exists flutter; then
    echo -e "${RED}❌ Flutter SDK não encontrado. Instale: https://flutter.dev/docs/get-started/install${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Dependências OK${NC}"

# Função para executar o servidor
run_server() {
    echo -e "${BLUE}🖥️  Iniciando servidor OAuth...${NC}"
    
    cd example/server
    
    # Verificar se config.dart existe
    if [ ! -f "lib/config.dart" ]; then
        echo -e "${YELLOW}⚠️  config.dart não encontrado, criando do template...${NC}"
        cp lib/config.example.dart lib/config.dart
        echo -e "${RED}🔧 IMPORTANTE: Configure suas credenciais Google em example/server/lib/config.dart${NC}"
        echo -e "${RED}📝 Veja as instruções em example/README.md${NC}"
        exit 1
    fi
    
    # Instalar dependências se necessário
    if [ ! -d ".dart_tool" ]; then
        echo -e "${YELLOW}📦 Instalando dependências do servidor...${NC}"
        dart pub get
    fi
    
    echo -e "${GREEN}🚀 Executando servidor em http://localhost:8080${NC}"
    dart run lib/main.dart
}

# Função para executar o app
run_app() {
    echo -e "${BLUE}📱 Iniciando app Flutter...${NC}"
    
    cd example/app
    
    # Instalar dependências se necessário
    if [ ! -d ".dart_tool" ]; then
        echo -e "${YELLOW}📦 Instalando dependências do app...${NC}"
        flutter pub get
    fi
    
    # Verificar se há dispositivos disponíveis
    echo -e "${YELLOW}🔍 Verificando dispositivos disponíveis...${NC}"
    flutter devices
    
    echo -e "${GREEN}🚀 Executando app Flutter...${NC}"
    
    # Tentar executar no Chrome primeiro, senão no primeiro dispositivo disponível
    if flutter devices | grep -q "Chrome"; then
        echo -e "${BLUE}🌐 Executando no Chrome...${NC}"
        flutter run -d chrome
    else
        echo -e "${BLUE}📱 Executando no primeiro dispositivo disponível...${NC}"
        flutter run
    fi
}

# Função para executar tudo
run_all() {
    echo -e "${BLUE}🔄 Executando servidor e app simultaneamente...${NC}"
    echo -e "${YELLOW}⚠️  O servidor será executado em segundo plano${NC}"
    
    # Executar servidor em background
    (
        cd example/server
        if [ ! -f "lib/config.dart" ]; then
            echo -e "${RED}❌ Configure primeiro: example/server/lib/config.dart${NC}"
            exit 1
        fi
        dart run lib/main.dart
    ) &
    
    SERVER_PID=$!
    
    # Aguardar um pouco para o servidor iniciar
    sleep 3
    
    # Executar app
    run_app
    
    # Parar servidor quando app terminar
    kill $SERVER_PID 2>/dev/null || true
}

# Função para mostrar ajuda
show_help() {
    echo -e "${BLUE}📖 Uso: $0 [comando]${NC}"
    echo ""
    echo "Comandos disponíveis:"
    echo -e "  ${GREEN}server${NC}    - Executar apenas o servidor OAuth"
    echo -e "  ${GREEN}app${NC}       - Executar apenas o app Flutter"
    echo -e "  ${GREEN}all${NC}       - Executar servidor e app simultaneamente"
    echo -e "  ${GREEN}setup${NC}     - Configurar arquivos de configuração"
    echo -e "  ${GREEN}help${NC}      - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0 server    # Executa apenas o servidor"
    echo "  $0 app       # Executa apenas o app"
    echo "  $0 all       # Executa ambos"
}

# Função para setup inicial
run_setup() {
    echo -e "${BLUE}🔧 Configuração inicial...${NC}"
    
    # Setup servidor
    if [ ! -f "example/server/lib/config.dart" ]; then
        echo -e "${YELLOW}📝 Criando config.dart do servidor...${NC}"
        cp example/server/lib/config.example.dart example/server/lib/config.dart
    fi
    
    # Setup app
    if [ ! -f "example/app/lib/config.dart" ]; then
        echo -e "${YELLOW}📝 Criando config.dart do app...${NC}"
        cp example/app/lib/config.example.dart example/app/lib/config.dart
    fi
    
    echo -e "${GREEN}✅ Arquivos de configuração criados${NC}"
    echo -e "${RED}🔧 PRÓXIMOS PASSOS:${NC}"
    echo "1. Configure suas credenciais Google em example/server/lib/config.dart"
    echo "2. Veja as instruções completas em example/README.md"
    echo "3. Execute: $0 server (para testar o servidor)"
    echo "4. Execute: $0 app (para testar o app)"
}

# Processar argumentos
case "${1:-}" in
    "server")
        run_server
        ;;
    "app")
        run_app
        ;;
    "all")
        run_all
        ;;
    "setup")
        run_setup
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    "")
        echo -e "${YELLOW}⚠️  Nenhum comando especificado${NC}"
        show_help
        ;;
    *)
        echo -e "${RED}❌ Comando desconhecido: $1${NC}"
        show_help
        exit 1
        ;;
esac