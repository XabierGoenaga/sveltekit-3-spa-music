FROM node:24-alpine AS build

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@10.13.0 --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

COPY . .
RUN pnpm gen-routes && pnpm build

# Serves the static SPA via plain Node HTTP — no nginx, no extra runtimes.
# SSL is handled by Dokploy's reverse proxy in front of this container.
FROM node:24-alpine AS runtime

LABEL org.opencontainers.image.title="music-spa"
LABEL org.opencontainers.image.description="Jellyfin + Plex music aggregator (Svelte 5 SPA)"
LABEL org.opencontainers.image.source="https://github.com/XabierGoenaga/music-spa"

ENV NODE_ENV=production
ENV PORT=8080
ENV HOST=0.0.0.0

WORKDIR /app

COPY --from=build /app/dist /app/dist
COPY docker/server.mjs /app/server.mjs

EXPOSE 8080

USER node

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -q -O - http://127.0.0.1:8080/ >/dev/null || exit 1

CMD ["node", "/app/server.mjs"]
