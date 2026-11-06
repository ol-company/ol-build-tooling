# syntax=docker/dockerfile:1
# Image cho chế độ phát triển trong container (hot reload): Node + pnpm, chạy bằng user node.
# Source được bind-mount từ máy; node_modules nằm trong volume riêng để nhanh và không lẫn với Windows.
ARG BASE_IMAGE=node:26-slim
FROM ${BASE_IMAGE}
RUN npm install -g pnpm@10 --no-fund --no-audit
ENV PNPM_HOME=/pnpm
RUN mkdir -p /pnpm /app && chown -R node:node /pnpm /app
USER node
WORKDIR /app
