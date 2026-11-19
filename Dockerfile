# Imagem da API da biblioteca.
# Build em dois estágios: o primeiro instala só as dependências de produção,
# o segundo copia o resultado para uma imagem enxuta que roda sem root.

FROM node:24-alpine AS dependencias
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:24-alpine
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app
COPY --from=dependencias /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# Usuário sem privilégios que já vem na imagem oficial do Node
USER node
EXPOSE 3000

# O Docker marca o container como unhealthy se /health parar de responder
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]
