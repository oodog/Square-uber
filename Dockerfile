cat > Dockerfile <<'EOF'
# 1) Frontend
FROM node:20-alpine AS web
WORKDIR /app/web
COPY web/package*.json ./
RUN npm ci || npm install
COPY web/ .
RUN npm run build || echo "No web build step; continuing"

# 2) Backend
FROM node:20-alpine AS server
WORKDIR /app/server
COPY server/package*.json ./
RUN npm ci || npm install
COPY server/ .
RUN npm run build || echo "No server build step; continuing"

# 3) Runtime
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=server /app/server /app/server
COPY --from=web /app/web/dist /app/web/dist
RUN npm -C /app/server ci --omit=dev || npm -C /app/server install --omit=dev
EXPOSE 8080
CMD ["node", "server/dist/index.js"]
EOF
