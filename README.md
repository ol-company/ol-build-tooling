# ol-build-tooling

Nguồn DUY NHẤT của cách build image và reusable workflow cho mọi repo OL-Platform.

| Đường dẫn | Nội dung |
|---|---|
| `dockerfiles/node-service/` | Backend Node: multi-stage, pnpm, BuildKit secret, non-root, nhãn truy vết |
| `dockerfiles/web-static/` | SPA: build Node → nginx-unprivileged, CSP, runtime `/config.json` |
| `dockerfiles/keycloak/` | Keycloak build tối ưu + CA của RDS |
| `dockerfiles/keycloak-config/` | keycloak-config-cli + realm từ `ol-infra/keycloak` |
| `dockerfiles/node-dev/` | Image dev (hot reload) cho local |
| `.github/workflows/node-ci.yml` | Lint, format, type-check, test + coverage |
| `.github/workflows/security-scan.yml` | gitleaks, CodeQL, Trivy fs, dependency-review |
| `.github/workflows/build-image.yml` | Lấy source + Dockerfile + build-config → build → Trivy → push → attestation → PR cập nhật digest |
| `.github/workflows/release.yml` | release-please (SemVer theo Conventional Commits) |
| `scripts/validate-build-config.sh` | Kiểm tra build-config: chỉ khóa cho phép, không có bí mật |
| `scripts/open-deploy-pr.sh` | Mở PR cập nhật `deploy/<env>/<module>.yaml` ở ol-infra |
| `scripts/pin-actions.sh` | Pin mọi `uses:` theo commit SHA |
| `tool-versions.env` | Phiên bản Trivy/gitleaks/hadolint/actionlint |

Repo gọi: `uses: ol-company/ol-build-tooling/.github/workflows/build-image.yml@<sha> # vX.Y.Z`.
Workflow tự xác định commit build-tooling đang chạy (claim `job_workflow_sha`) để checkout đúng Dockerfile.
