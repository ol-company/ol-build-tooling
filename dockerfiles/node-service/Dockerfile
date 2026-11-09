# syntax=docker/dockerfile:1
# =============================================================================
# Dockerfile DÙNG CHUNG cho mọi backend Node.js/TypeScript (iam-service, warehouse-service, bff).
# Build context  = thư mục source của service (có package.json, pnpm-lock.yaml, src/, migrations/)
# Build arg      = lấy từ ol-infra/build-config/<env>/<module>.env (đã được kiểm tra hợp lệ)
# Build secret   = npm_token (đọc GitHub Packages) — mount tạm thời, KHÔNG nằm trong layer nào
# =============================================================================
ARG BASE_IMAGE=node:26-slim

# ---------- base: Node + pnpm ----------
FROM ${BASE_IMAGE} AS base
# Node 25+ không còn kèm Corepack → cài pnpm trực tiếp, pin major
RUN npm install -g pnpm@10 --no-fund --no-audit && npm cache clean --force
ENV PNPM_HOME=/pnpm CI=true
WORKDIR /app

# ---------- deps: cài toàn bộ dependency (kể cả dev để build) ----------
FROM base AS deps
# Chỉ copy file manifest trước → layer này được cache khi chỉ sửa code
COPY package.json pnpm-lock.yaml .npmrc ./
RUN printf '%s\n' '//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}' > /root/.npmrc
# secret mount: token chỉ tồn tại trong lệnh RUN này; cache mount: tái dùng store pnpm giữa các lần build
RUN --mount=type=secret,id=npm_token,env=NODE_AUTH_TOKEN \
    --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm config set store-dir /pnpm/store && \
    pnpm install --frozen-lockfile

# ---------- build: biên dịch TypeScript ----------
FROM deps AS build
COPY . .
RUN pnpm run build

# ---------- test (tùy chọn): docker build --target test để chạy unit test trong cùng môi trường ----------
FROM build AS test
RUN pnpm run test:unit

# ---------- prod-deps: bỏ devDependencies ----------
FROM deps AS prod-deps
RUN pnpm prune --prod

# ---------- runtime: image cuối, tối giản ----------
FROM ${BASE_IMAGE} AS runtime
# Nhãn truy vết: image này build từ commit nào, Dockerfile nào, config nào, cho môi trường nào
ARG SOURCE_REPOSITORY=unknown
ARG SOURCE_REVISION=unknown
ARG VERSION=0.0.0
ARG DOCKERFILE_REF=unknown
ARG CONFIG_REF=unknown
ARG TARGET_ENV=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.source="https://github.com/${SOURCE_REPOSITORY}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      io.ol-platform.dockerfile.ref="${DOCKERFILE_REF}" \
      io.ol-platform.config.ref="${CONFIG_REF}" \
      io.ol-platform.target-env="${TARGET_ENV}"

ENV NODE_ENV=production
WORKDIR /app

# Chứng chỉ CA của Amazon RDS để kết nối DB với TLS xác minh đầy đủ (rejectUnauthorized: true)
ADD --chmod=644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-global-bundle.pem

# Chỉ copy thứ cần để chạy; chủ sở hữu là user "node" (uid 1000) có sẵn trong image Node
COPY --from=prod-deps --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/migrations ./migrations
COPY --chown=node:node package.json ./

# Chạy bằng user không phải root
USER node
EXPOSE 3000

# Docker/Compose dùng healthcheck này; ECS khai báo healthcheck riêng trong task definition
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health/live').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]

STOPSIGNAL SIGTERM
# --import: nạp OpenTelemetry trước app (chỉ bật khi có OTEL_EXPORTER_OTLP_ENDPOINT)
CMD ["node", "--enable-source-maps", "--import", "@ol/node-kit/otel-register", "dist/main.js"]
