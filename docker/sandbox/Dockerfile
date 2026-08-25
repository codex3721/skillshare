# Build arguments (must be before first FROM for cross-stage visibility)
ARG NODE_VERSION=24
ARG PNPM_VERSION=10.28.0
ARG GO_VERSION=1.25.5

# Stage 1: Build frontend assets (for playground UI)
FROM node:${NODE_VERSION}-bookworm-slim AS ui-builder
ARG PNPM_VERSION
RUN npm install -g pnpm@${PNPM_VERSION}
WORKDIR /ui
COPY ui/package.json ui/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY ui/ ./
RUN pnpm run build

# Stage 2: Go sandbox with pre-built frontend
FROM golang:${GO_VERSION}-bookworm

# Use a CN mirror: deb.debian.org is intermittently unreachable from some networks.
RUN sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' \
        /etc/apt/sources.list.d/debian.sources
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash git ca-certificates curl jq sudo procps \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Go development tools
# air pinned: v1.67.2+ requires go >= 1.26, image runs GO_VERSION with GOTOOLCHAIN=local
# GOPROXY/GOSUMDB: sum.golang.org is unreachable from some networks; use a proxy.
ENV GOPROXY=https://goproxy.cn,direct
ENV GOSUMDB=off
RUN go install github.com/air-verse/air@v1.67.1 \
    && go install github.com/go-delve/delve/cmd/dlv@latest

# Copy node runtime from ui-builder stage (for devcontainer / interactive use)
COPY --from=ui-builder /usr/local/bin/node /usr/local/bin/
COPY --from=ui-builder /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -sf ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack
ARG PNPM_VERSION
RUN npm install -g pnpm@${PNPM_VERSION}

# Copy pre-built frontend for playground UI cache
COPY --from=ui-builder /ui/dist /ui-dist

COPY docker/sandbox/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace

COPY go.mod go.sum ./
RUN go mod download
RUN mkdir -p /go/build-cache /go/pkg/mod && chmod -R 0777 /go/build-cache /go/pkg/mod

# Bake a production binary at build time. Sandbox services that mount /workspace
# still use `go run` from the mounted source; deployment (docker/docker-compose.yml)
# runs this binary directly with no source mount and no Go caches.
# VERSION is injected via -X main.version (same scheme as .goreleaser.yaml) so the
# dev-mode "update available" simulation in handler_version.go stays off.
ARG VERSION=0.20.25
ARG TARGETARCH
ENV SKILLSHARE_VERSION=${VERSION}
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" \
    -o /usr/local/bin/skillshare ./cmd/skillshare

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "-c", "./scripts/test.sh"]
