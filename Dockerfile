# Usa a imagem base Node.js Bullseye
FROM node:24-bullseye

# Instala o git e outras ferramentas úteis
RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

# Instala o Next.js e Vite globalmente para acesso ao CLI
RUN npm install -g next@latest vite@latest

# Define o diretório de trabalho como a pasta do projeto Next.js
# Isso garante que todos os comandos (incluindo o CMD final) sejam executados aqui.
WORKDIR /root/app

# Copia e instala dependências DENTRO do diretório do Next.js
COPY app/package*.json ./

RUN npm install

# Copia o restante do código-fonte do seu projeto
COPY app/ .

# EXIGÊNCIA PARA PRODUÇÃO: Executar o build
RUN npm run build

# Expõe a porta que sua aplicação utiliza
EXPOSE 3000

# NOVO COMANDO CHAVE: Inicia o servidor de produção do Next.js
CMD ["npm", "start"]
