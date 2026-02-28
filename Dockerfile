FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat openssl
WORKDIR /app
COPY package*.json ./
RUN npm ci

# Rebuild the source code
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
RUN mkdir -p public
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production

# Required by Prisma engine binaries on alpine
RUN apk add --no-cache libc6-compat openssl

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Install Prisma CLI matching project version for db push at startup
RUN npm install -g prisma@5.22.0 --quiet
# Pre-download engine binaries at build time (as root) so runtime write isn't needed
RUN prisma version 2>&1 || true
# Allow nextjs user to write to the global prisma dir if needed
RUN chown -R nextjs:nodejs /usr/local/lib/node_modules/prisma

# Copy built files
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/.prisma ./node_modules/.prisma

USER nextjs

EXPOSE 3000
ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

# Ensure data dir exists, push schema, then start
CMD ["sh", "-c", "mkdir -p prisma/data && prisma db push --skip-generate 2>&1 && node server.js"]
