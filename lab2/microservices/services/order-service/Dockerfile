# syntax=docker/dockerfile:1
# ---- Stage 1: cài dependency production ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

# ---- Stage 2: image chạy, user "node" (không phải root) ----
FROM node:22-alpine
LABEL org.opencontainers.image.title="nt548-order-service" \
      org.opencontainers.image.description="NT548 Lab 02 - Order service (Express)"
ENV NODE_ENV=production PORT=3000
WORKDIR /app
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src
# user "node" có sẵn trong image node (uid 1000)
USER 1000
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
CMD ["node", "src/server.js"]
