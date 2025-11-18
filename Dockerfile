# Usa a imagem base Node.js Bullseye
FROM node:24-bullseye

# Instala o git e outras ferramentas úteis
RUN apt-get update && apt-get install -y git curl && rm -rf /var/lib/apt/lists/*

# Instala o Next.js e Vite globalmente para acesso ao CLI
RUN npm install -g next@latest vite@latest

# Define o diretório de trabalho dentro do contêiner
WORKDIR /root

# Copia o package.json e package-lock.json (se existirem) para instalar as dependências
COPY package*.json ./

# Instala as dependências do Node.js
# Se você não tiver dependências, esta linha é opcional, mas recomendada
RUN npm install

# Copia todo o código-fonte do seu projeto para o diretório de trabalho
COPY . .

# Expõe a porta que sua aplicação utiliza
EXPOSE 3000

# Este é o comando chave: ele define o que rodar quando o contêiner inicia
# Garante que 'node server.js' seja executado automaticamente
CMD ["node", "server.js"]
