# Three stages. `deps` resolves the production dependencies, `build` compiles
# TypeScript, and the final image copies both results in. Nothing that only
# exists to produce the build — pnpm, tsc, vitest, eslint — ships in the image
# that runs.

# ---------- production dependencies ----------
FROM node:22-alpine AS deps
WORKDIR /app

# devEngines.packageManager in package.json names pnpm 11; corepack does not
# read that field, so pin it here instead.
RUN npm install -g pnpm@11

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
# --prod skips devDependencies. pnpm downloads into a content-addressable
# store and links from it, so the store has to go in the same layer or it
# doubles the size of everything installed.
RUN pnpm install --frozen-lockfile --prod \
  && rm -rf "$(pnpm store path)" /root/.npm /root/.cache

# ---------- build ----------
FROM node:22-alpine AS build
WORKDIR /app

RUN npm install -g pnpm@11

# Manifests first: this layer is cached and only redone when a dependency
# changes, not on every source edit. pnpm-workspace.yaml carries the
# allowBuilds setting esbuild needs.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
# Compiles to dist/ and copies the .sql migrations next to it.
RUN pnpm build

# ---------- runtime ----------
FROM node:22-alpine
WORKDIR /app

# Read by logger.ts (JSON instead of pino-pretty) and by config.ts.
ENV NODE_ENV=production

# No package manager here: the dependency tree arrives already resolved.
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
# version.ts reads the version from here; nothing else in the image needs it.
COPY package.json ./

# The node images ship an unprivileged `node` user; nothing here needs root.
USER node

# Documentation only. The real port comes from PORT, which Railway sets.
EXPOSE 3000

CMD ["node", "dist/index.js"]
