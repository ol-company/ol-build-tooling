# syntax=docker/dockerfile:1
# =============================================================================
# Dockerfile cho frontend SPA tĩnh (ol-web-admin): build bằng Node, phục vụ bằng nginx không root.
# Build context "tooling" (named context) chứa nginx.conf và script runtime config của thư mục này.
# Biến VITE_* là BUILD-TIME config: được nhúng vào bundle, đổi giá trị phải build lại image.
# Cấu hình theo môi trường còn lại là RUNTIME config: /config.json sinh lúc container khởi động.
# =============================================================================
ARG BASE_IMAGE=node:26-slim
ARG NGINX_IMAGE=nginxinc/nginx-unprivileged:stable-alpine

FROM ${BASE_IMAGE} AS build
RUN npm install -g pnpm@10 --no-fund --no-audit
ENV PNPM_HOME=/pnpm CI=true
WORKDIR /app
COPY package.json pnpm-lock.yaml .npmrc ./
RUN --mount=type=secret,id=npm_token,env=NODE_AUTH_TOKEN \
    --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm config set store-dir /pnpm/store && pnpm install --frozen-lockfile
COPY . .
# Build-time config công khai (không bao giờ đặt bí mật vào VITE_*)
ARG VITE_BUILD_VERSION=dev
ENV VITE_BUILD_VERSION=${VITE_BUILD_VERSION}
RUN pnpm run build

FROM ${NGINX_IMAGE} AS runtime
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

# Image nginx-unprivileged đã chạy bằng uid 101 và lắng nghe cổng 8080
COPY --from=tooling nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=tooling security-headers.conf /etc/nginx/snippets/security-headers.conf
COPY --from=tooling --chmod=755 40-runtime-config.sh /docker-entrypoint.d/40-runtime-config.sh
COPY --from=build /app/dist /usr/share/nginx/html
# Khai báo tường minh user nginx (uid 101) của image gốc để không phụ thuộc mặc định của nó
USER 101:101
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1
