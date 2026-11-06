# syntax=docker/dockerfile:1
# =============================================================================
# Áp cấu hình realm Keycloak (client, scope, chính sách mật khẩu, MFA...) như CODE, idempotent.
# Chạy như task một lần sau mỗi lần thay đổi cấu hình realm (local: docker compose; AWS: ECS run-task).
# Build context: thư mục ol-infra/keycloak (chứa realm-ol.yaml).
# Giá trị bí mật (client secret, SMTP) KHÔNG nằm trong file — thế vào lúc chạy từ biến môi trường.
# =============================================================================
# [CHƯA XÁC MINH] Tag phải tương thích phiên bản Keycloak; kiểm tại https://hub.docker.com/r/adorsys/keycloak-config-cli/tags
ARG KCC_IMAGE=adorsys/keycloak-config-cli:6.4.0-26.1.0
FROM ${KCC_IMAGE}
ARG SOURCE_REVISION=unknown
ARG DOCKERFILE_REF=unknown
ARG CONFIG_REF=unknown
ARG TARGET_ENV=unknown
LABEL org.opencontainers.image.revision="${SOURCE_REVISION}" \
      io.ol-platform.dockerfile.ref="${DOCKERFILE_REF}" \
      io.ol-platform.config.ref="${CONFIG_REF}" \
      io.ol-platform.target-env="${TARGET_ENV}"
COPY realm-ol.yaml /config/realm-ol.yaml
ENV IMPORT_FILES_LOCATIONS=/config/realm-ol.yaml \
    IMPORT_VARSUBSTITUTION_ENABLED=true \
    IMPORT_MANAGED_CLIENT=no-delete
# Image gốc đã chạy bằng nobody (65534); khai báo tường minh để không phụ thuộc mặc định của image gốc
USER 65534:65534
