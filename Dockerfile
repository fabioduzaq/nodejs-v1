# Usa a imagem base Node.js Bullseye
FROM node:24-bullseye

# Instala o git e outras ferramentas úteis
RUN apt-get update && apt-get install -y \
    git \
    curl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Instala o Next.js e Vite globalmente para acesso ao CLI
RUN npm install -g next@latest vite@latest

# Define o diretório de trabalho
WORKDIR /root

# Cria diretório para a aplicação
RUN mkdir -p /root/app

# Cria script de monitoramento e gerenciamento
RUN cat > /root/monitor.sh << 'EOFSCRIPT'
#!/bin/bash

# ============================================
# CONFIGURAÇÕES (Todas via variáveis de ambiente)
# ============================================
REPO_URL="${GIT_REPO_URL:-https://github.com/fabioduzaq/app-movaa-v2.git}"
BRANCH="${GIT_BRANCH:-az-movaa-v2}"  # Branch configurável (padrão: az-movaa-v2)
APP_DIR="${APP_DIR:-/root/app}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"  # Intervalo em segundos
PORT="${PORT:-3000}"  # Porta da aplicação

# Configuração de autenticação
if [ -n "$GIT_TOKEN" ]; then
    # Se tiver token, substitui na URL
    REPO_URL=$(echo "$REPO_URL" | sed "s|https://|https://${GIT_TOKEN}@|")
fi

PID_FILE="/tmp/app.pid"
LOG_FILE="/tmp/app.log"

# ============================================
# FUNÇÕES AUXILIARES
# ============================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /tmp/monitor.log
}

# Para a aplicação
stop_app() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat $PID_FILE)
        if ps -p $PID > /dev/null 2>&1; then
            log "🛑 Parando aplicação (PID: $PID)..."
            kill $PID 2>/dev/null || true
            wait $PID 2>/dev/null || true
        fi
        rm -f $PID_FILE
    fi
}

# Inicia a aplicação
start_app() {
    log "🚀 Iniciando aplicação..."
    cd $APP_DIR || {
        log "❌ Erro: diretório $APP_DIR não existe"
        return 1
    }
    
    # Verifica se package.json existe
    if [ ! -f "package.json" ]; then
        log "❌ Erro: package.json não encontrado"
        return 1
    fi
    
    # Instala dependências se necessário
    if [ ! -d "node_modules" ] || [ "package.json" -nt "node_modules" ]; then
        log "📦 Instalando/atualizando dependências..."
        npm install || {
            log "❌ Erro ao instalar dependências"
            return 1
        }
    fi
    
    # Faz build se necessário
    if [ ! -d ".next" ] || [ "package.json" -nt ".next" ] || [ -n "$FORCE_REBUILD" ]; then
        log "🔨 Fazendo build da aplicação..."
        npm run build || {
            log "❌ Erro ao fazer build"
            return 1
        }
        unset FORCE_REBUILD
    fi
    
    # Configura a porta se necessário (para Next.js)
    export PORT=$PORT
    
    # Inicia a aplicação em background
    log "▶️  Iniciando servidor Next.js na porta $PORT..."
    npm start > $LOG_FILE 2>&1 &
    APP_PID=$!
    echo $APP_PID > $PID_FILE
    
    # Aguarda um pouco para verificar se iniciou corretamente
    sleep 3
    if ps -p $APP_PID > /dev/null 2>&1; then
        log "✅ Aplicação iniciada com sucesso (PID: $APP_PID)"
        log "📋 Logs disponíveis em: $LOG_FILE"
        return 0
    else
        log "❌ Aplicação não iniciou corretamente. Verifique os logs: $LOG_FILE"
        cat $LOG_FILE
        rm -f $PID_FILE
        return 1
    fi
}

# Clona o repositório pela primeira vez
clone_repo() {
    log "📥 Clonando repositório pela primeira vez..."
    log "   URL: $REPO_URL"
    log "   Branch: $BRANCH"
    
    git clone -b $BRANCH $REPO_URL $APP_DIR || {
        log "❌ Erro ao clonar repositório"
        log "   Verifique se o branch '$BRANCH' existe e se as credenciais estão corretas"
        return 1
    }
    
    log "✅ Repositório clonado com sucesso"
    return 0
}

# Atualiza o repositório e aplica alterações
update_repo() {
    cd $APP_DIR || {
        log "❌ Erro: diretório $APP_DIR não existe"
        return 1
    }
    
    # Verifica se é um repositório git
    if [ ! -d ".git" ]; then
        log "⚠️  Não é um repositório git. Tentando clonar..."
        cd /root
        rm -rf $APP_DIR
        clone_repo || return 1
        cd $APP_DIR
    fi
    
    # Configura o remote se necessário
    if ! git remote get-url origin &>/dev/null; then
        log "📡 Configurando remote..."
        git remote add origin $REPO_URL 2>/dev/null || \
        git remote set-url origin $REPO_URL
    fi
    
    # Atualiza referências do remote
    log "🔄 Buscando atualizações do remote..."
    git fetch origin $BRANCH 2>&1 | tee -a /tmp/monitor.log || {
        log "❌ Erro ao fazer fetch do remote"
        return 1
    }
    
    # Obtém os commits
    LOCAL_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")
    REMOTE_COMMIT=$(git rev-parse origin/$BRANCH 2>/dev/null || echo "")
    
    if [ -z "$REMOTE_COMMIT" ]; then
        log "⚠️  Branch remoto '$BRANCH' não encontrado"
        log "   Verifique se o branch existe no repositório"
        return 1
    fi
    
    # Compara commits
    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
        log "🆕 ==========================================="
        log "🆕 NOVO COMMIT DETECTADO!"
        log "🆕 ==========================================="
        log "   Branch: $BRANCH"
        log "   Local:  ${LOCAL_COMMIT:0:7}"
        log "   Remoto: ${REMOTE_COMMIT:0:7}"
        
        # Obtém informações do commit
        COMMIT_MSG=$(git log -1 --pretty=%B $REMOTE_COMMIT 2>/dev/null || echo "N/A")
        COMMIT_AUTHOR=$(git log -1 --pretty=%an $REMOTE_COMMIT 2>/dev/null || echo "N/A")
        COMMIT_DATE=$(git log -1 --pretty=%cd $REMOTE_COMMIT 2>/dev/null || echo "N/A")
        
        log "   Autor: $COMMIT_AUTHOR"
        log "   Data: $COMMIT_DATE"
        log "   Mensagem: $COMMIT_MSG"
        log ""
        
        # Faz checkout do branch correto
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
            log "🔀 Fazendo checkout do branch $BRANCH..."
            git checkout $BRANCH 2>/dev/null || git checkout -b $BRANCH origin/$BRANCH
        fi
        
        # Faz pull das alterações
        log "⬇️  Fazendo pull das alterações do branch $BRANCH..."
        git pull origin $BRANCH || {
            log "❌ Erro ao fazer pull"
            return 1
        }
        
        log "✅ Código atualizado com sucesso"
        log ""
        
        # Marca para rebuild
        FORCE_REBUILD=1
        
        # Para a aplicação atual
        stop_app
        
        # Aguarda um pouco antes de reiniciar
        sleep 2
        
        # Reinicia a aplicação com as novas alterações
        start_app
        
        log "🎉 Aplicação atualizada e reiniciada com sucesso!"
        log "==========================================="
        return 0
    else
        return 1
    fi
}

# ============================================
# FUNÇÃO PRINCIPAL
# ============================================

main() {
    log "==========================================="
    log "🚀 INICIANDO MONITOR DE COMMITS"
    log "==========================================="
    log "Repositório: $REPO_URL"
    log "Branch: $BRANCH"
    log "Diretório: $APP_DIR"
    log "Porta: $PORT"
    log "Intervalo de verificação: $CHECK_INTERVAL segundos"
    log "==========================================="
    log ""
    
    # Valida se o branch foi configurado
    if [ -z "$BRANCH" ]; then
        log "❌ Erro: GIT_BRANCH não configurado"
        exit 1
    fi
    
    # Clona o repositório se não existir
    if [ ! -d "$APP_DIR/.git" ]; then
        clone_repo || {
            log "❌ Falha ao clonar repositório. Encerrando..."
            exit 1
        }
    fi
    
    # Faz build inicial
    log "🔨 Fazendo build inicial..."
    cd $APP_DIR
    npm install || {
        log "❌ Erro ao instalar dependências iniciais"
        exit 1
    }
    npm run build || {
        log "❌ Erro no build inicial"
        exit 1
    }
    
    # Inicia a aplicação pela primeira vez
    start_app || {
        log "❌ Falha ao iniciar aplicação. Encerrando..."
        exit 1
    }
    
    log ""
    log "✅ Sistema iniciado com sucesso!"
    log "🌐 Aplicação rodando na porta $PORT"
    log "🌿 Monitorando branch: $BRANCH"
    log "👀 Verificando commits a cada $CHECK_INTERVAL segundos..."
    log "   Pressione Ctrl+C para parar"
    log ""
    
    # Loop de monitoramento
    while true; do
        sleep $CHECK_INTERVAL
        update_repo || true
    done
}

# Trap para garantir limpeza ao sair
trap 'log "🛑 Recebido sinal de parada. Encerrando..."; stop_app; exit 0' SIGTERM SIGINT

# Inicia o sistema
main
EOFSCRIPT

# Torna o script executável
RUN chmod +x /root/monitor.sh

# Expõe a porta (padrão 3000, mas será configurável via variável)
EXPOSE 3000

# Comando principal: inicia o monitoramento
CMD ["/root/monitor.sh"]
