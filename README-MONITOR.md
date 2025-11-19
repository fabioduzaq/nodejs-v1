# Docker Monitor - Monitoramento Automático de Commits

Sistema automatizado que monitora commits do repositório GitHub e aplica alterações automaticamente no container Docker.

## 🚀 Funcionalidades

- ✅ Clona automaticamente o branch `az-movaa-v2` do repositório
- ✅ Faz build inicial da aplicação Next.js
- ✅ Monitora commits a cada 60 segundos (configurável)
- ✅ Detecta novos commits automaticamente
- ✅ Aplica alterações (pull, rebuild, restart) sem intervenção manual
- ✅ Logs detalhados de todas as operações

## 📋 Pré-requisitos

- Docker instalado
- Docker Compose (opcional, mas recomendado)
- Token de acesso do GitHub (já configurado)

## ⚙️ Configuração

### Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto com as seguintes variáveis:

```bash
# Configurações do Git
GIT_REPO_URL=https://github.com/fabioduzaq/app-movaa-v2.git
GIT_BRANCH=az-movaa-v2
GIT_TOKEN=seu_token_github_aqui

# Configurações da aplicação
PORT=3000
CHECK_INTERVAL=60

# Diretório da aplicação (dentro do container)
APP_DIR=/root/app
```

### Variáveis Disponíveis

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `GIT_REPO_URL` | `https://github.com/fabioduzaq/app-movaa-v2.git` | URL do repositório Git |
| `GIT_BRANCH` | `az-movaa-v2` | Branch para monitorar |
| `GIT_TOKEN` | - | Token de acesso do GitHub (obrigatório para repositórios privados) |
| `CHECK_INTERVAL` | `60` | Intervalo de verificação em segundos |
| `PORT` | `3000` | Porta da aplicação Next.js |
| `APP_DIR` | `/root/app` | Diretório onde a aplicação será clonada |

## 🏃 Como Usar

### Opção 1: Usando o Script Helper (Recomendado)

```bash
# Constrói e executa o container
./run.sh run

# Apenas constrói a imagem
./run.sh build

# Usa docker-compose
./run.sh compose

# Ver logs
./run.sh logs

# Parar container
./run.sh stop

# Reiniciar container
./run.sh restart
```

### Opção 2: Usando Docker Compose

```bash
# Iniciar
docker-compose up -d

# Ver logs
docker-compose logs -f

# Parar
docker-compose down

# Reiniciar
docker-compose restart
```

### Opção 3: Usando Docker diretamente

```bash
# Build da imagem
docker build -t app-monitor:latest .

# Executar container
docker run -d \
  --name app-monitor \
  -p 3000:3000 \
  -e GIT_REPO_URL="https://github.com/fabioduzaq/app-movaa-v2.git" \
  -e GIT_BRANCH="az-movaa-v2" \
  -e GIT_TOKEN="seu_token_github_aqui" \
  -e CHECK_INTERVAL=60 \
  --restart unless-stopped \
  app-monitor:latest

# Ver logs
docker logs -f app-monitor
```

## 📊 Monitoramento

### Ver Logs do Monitor

```bash
# Logs do container
docker logs -f app-monitor

# Ou usando docker-compose
docker-compose logs -f
```

### Ver Logs da Aplicação

```bash
# Logs da aplicação Next.js (dentro do container)
docker exec app-monitor tail -f /tmp/app.log

# Logs do monitor
docker exec app-monitor tail -f /tmp/monitor.log
```

## 🔄 Fluxo de Funcionamento

1. **Inicialização:**
   - Container inicia e clona o branch `az-movaa-v2`
   - Instala dependências (`npm install`)
   - Faz build inicial (`npm run build`)
   - Inicia a aplicação (`npm start`)

2. **Monitoramento:**
   - A cada 60 segundos (ou intervalo configurado), verifica novos commits
   - Compara commit local vs remoto

3. **Aplicação de Alterações:**
   - Quando detecta novo commit:
     - Faz `git pull` das alterações
     - Reinstala dependências se necessário
     - Faz rebuild da aplicação
     - Para a aplicação antiga
     - Inicia a nova versão

## 🛠️ Comandos Úteis

```bash
# Ver status do container
docker ps | grep app-monitor

# Entrar no container
docker exec -it app-monitor bash

# Ver processos rodando
docker exec app-monitor ps aux

# Verificar branch atual
docker exec app-monitor sh -c "cd /root/app && git branch"

# Ver último commit
docker exec app-monitor sh -c "cd /root/app && git log -1"

# Forçar rebuild manual
docker exec app-monitor sh -c "cd /root/app && git pull && npm install && npm run build"
```

## 🔧 Troubleshooting

### Container não inicia

```bash
# Ver logs de erro
docker logs app-monitor

# Verificar se o token está correto
docker exec app-monitor env | grep GIT_TOKEN
```

### Erro ao clonar repositório

- Verifique se o token está correto
- Verifique se o branch existe no repositório
- Verifique se o repositório é privado (precisa de token)

### Aplicação não atualiza

```bash
# Verificar se está monitorando o branch correto
docker exec app-monitor sh -c "cd /root/app && git branch -a"

# Verificar último commit local vs remoto
docker exec app-monitor sh -c "cd /root/app && git fetch && git log HEAD..origin/az-movaa-v2"
```

### Porta já em uso

```bash
# Alterar porta no .env ou docker-compose.yml
PORT=3001

# Ou usar porta diferente no docker run
docker run -p 3001:3000 ...
```

## 📝 Notas

- O container reinicia automaticamente se parar (graças ao `restart: unless-stopped`)
- Os logs são persistidos em `/tmp` dentro do container
- O monitor verifica commits mesmo se a aplicação estiver rodando
- O build é feito automaticamente quando detecta alterações no `package.json`

## 🔒 Segurança

⚠️ **IMPORTANTE**: O token do GitHub está exposto no `.env`. Certifique-se de:
- Não commitar o arquivo `.env` no Git
- Adicionar `.env` ao `.gitignore`
- Usar tokens com permissões mínimas necessárias
- Rotacionar tokens periodicamente

## 📞 Suporte

Para problemas ou dúvidas, verifique os logs do container:
```bash
docker logs -f app-monitor
```

