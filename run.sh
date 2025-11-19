#!/bin/bash

# Script helper para facilitar build e execução do container

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Docker Monitor - Helper Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Carrega variáveis do .env se existir
if [ -f .env ]; then
    echo -e "${GREEN}✓${NC} Carregando variáveis do .env"
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${YELLOW}⚠${NC} Arquivo .env não encontrado. Usando valores padrão."
fi

# Função para build
build() {
    echo -e "${BLUE}🔨 Construindo imagem Docker...${NC}"
    docker build -t app-monitor:latest .
    echo -e "${GREEN}✅ Build concluído!${NC}"
}

# Função para executar
run() {
    echo -e "${BLUE}🚀 Iniciando container...${NC}"
    
    # Para container existente se estiver rodando
    if docker ps -a | grep -q app-monitor; then
        echo -e "${YELLOW}⚠${NC} Parando container existente..."
        docker stop app-monitor 2>/dev/null || true
        docker rm app-monitor 2>/dev/null || true
    fi
    
    # Executa o container
    docker run -d \
        --name app-monitor \
        -p 3000:3000 \
        -e GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/fabioduzaq/app-movaa-v2.git}" \
        -e GIT_BRANCH="${GIT_BRANCH:-az-movaa-v2}" \
        -e GIT_TOKEN="${GIT_TOKEN}" \
        -e PORT="${PORT:-3000}" \
        -e CHECK_INTERVAL="${CHECK_INTERVAL:-60}" \
        -e APP_DIR="${APP_DIR:-/root/app}" \
        --restart unless-stopped \
        app-monitor:latest
    
    echo -e "${GREEN}✅ Container iniciado!${NC}"
    echo ""
    echo -e "${BLUE}📋 Comandos úteis:${NC}"
    echo "  - Ver logs: docker logs -f app-monitor"
    echo "  - Parar: docker stop app-monitor"
    echo "  - Remover: docker rm -f app-monitor"
    echo "  - Status: docker ps | grep app-monitor"
}

# Função para usar docker-compose
compose() {
    echo -e "${BLUE}🚀 Iniciando com docker-compose...${NC}"
    docker-compose up -d
    echo -e "${GREEN}✅ Container iniciado!${NC}"
    echo ""
    echo -e "${BLUE}📋 Comandos úteis:${NC}"
    echo "  - Ver logs: docker-compose logs -f"
    echo "  - Parar: docker-compose down"
    echo "  - Status: docker-compose ps"
}

# Função para ver logs
logs() {
    if [ -f docker-compose.yml ]; then
        docker-compose logs -f
    else
        docker logs -f app-monitor
    fi
}

# Função para parar
stop() {
    if [ -f docker-compose.yml ]; then
        docker-compose down
    else
        docker stop app-monitor 2>/dev/null || true
        echo -e "${GREEN}✅ Container parado!${NC}"
    fi
}

# Menu principal
case "$1" in
    build)
        build
        ;;
    run)
        build
        run
        ;;
    compose|up)
        compose
        ;;
    logs)
        logs
        ;;
    stop|down)
        stop
        ;;
    restart)
        stop
        sleep 2
        if [ -f docker-compose.yml ]; then
            compose
        else
            run
        fi
        ;;
    *)
        echo "Uso: $0 {build|run|compose|logs|stop|restart}"
        echo ""
        echo "Comandos:"
        echo "  build     - Apenas constrói a imagem"
        echo "  run       - Constrói e executa o container"
        echo "  compose   - Usa docker-compose para iniciar"
        echo "  logs      - Mostra os logs do container"
        echo "  stop      - Para o container"
        echo "  restart   - Reinicia o container"
        exit 1
        ;;
esac

