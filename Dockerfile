# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# # Enable corepack and install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

# Copy files and install dependencies
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy source code to build
COPY tsconfig.json ./
COPY src ./src

# Build and prune
RUN pnpm build && pnpm prune --prod

# Stage 2: Production
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

EXPOSE 8000

CMD ["npm", "start"]
