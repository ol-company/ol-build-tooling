# syntax=docker/dockerfile:1
# =============================================================================
# Keycloak đã "build tối ưu": cấu hình build-time (DB vendor, health, metrics) được biên dịch sẵn
# → container khởi động nhanh với "start --optimized". Cấu hình runtime (URL DB, hostname, mật khẩu)
# cấp qua biến môi trường KC_* khi chạy.
# Build context: chính thư mục này (không cần source repo).
# =============================================================================
ARG KEYCLOAK_IMAGE=quay.io/keycloak/keycloak:26.8.1

FROM ${KEYCLOAK_IMAGE} AS builder
ENV KC_DB=postgres \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true
RUN /opt/keycloak/bin/kc.sh build

FROM ${KEYCLOAK_IMAGE}
ARG SOURCE_REPOSITORY=unknown
ARG SOURCE_REVISION=unknown
ARG DOCKERFILE_REF=unknown
ARG CONFIG_REF=unknown
ARG TARGET_ENV=unknown
ARG BUILD_DATE=unknown
LABEL org.opencontainers.image.source="https://github.com/${SOURCE_REPOSITORY}" \
      org.opencontainers.image.revision="${SOURCE_REVISION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      io.ol-platform.dockerfile.ref="${DOCKERFILE_REF}" \
      io.ol-platform.config.ref="${CONFIG_REF}" \
      io.ol-platform.target-env="${TARGET_ENV}"
COPY --from=builder /opt/keycloak/ /opt/keycloak/
# CA của RDS để JDBC dùng sslmode=verify-full (xác minh chứng chỉ DB)
ADD --chown=1000:0 --chmod=644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /opt/keycloak/conf/rds-global-bundle.pem
USER 1000
EXPOSE 8080 9000
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized"]
