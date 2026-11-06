#!/usr/bin/env bash
# Mở Pull Request ở ol-infra cập nhật deploy/<env>/<module>.yaml bằng image digest mới.
#  - dev, staging: bật auto-merge → merge khi check của ol-infra xanh → workflow deploy chạy
#  - prod: KHÔNG auto-merge → cần CODEOWNERS (platform + security) duyệt, sau đó environment "production" duyệt
# Biến môi trường bắt buộc: GH_TOKEN OWNER MODULE DEPLOY_ENV DIGEST SOURCE_REPOSITORY SOURCE_REF CONFIG_SHA TOOLING_SHA VERSION
set -euo pipefail

[[ "$DEPLOY_ENV" =~ ^(dev|staging|prod)$ ]] || { echo "DEPLOY_ENV không hợp lệ" >&2; exit 1; }
[[ "$DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "DIGEST không hợp lệ" >&2; exit 1; }

workdir=$(mktemp -d)
gh repo clone "$OWNER/ol-infra" "$workdir" -- --depth 1 --quiet
cd "$workdir"
file="deploy/$DEPLOY_ENV/$MODULE.yaml"
[[ -f "$file" ]] || { echo "Không có $file trong ol-infra" >&2; exit 1; }

branch="bot/$DEPLOY_ENV/$MODULE-${DIGEST:7:12}"
git switch -c "$branch"

# yq (mikefarah) có sẵn trên runner ubuntu của GitHub; strenv() đọc biến môi trường an toàn (không chèn lệnh)
yq -i '
  .image.digest = strenv(DIGEST) |
  .source.repository = strenv(SOURCE_REPOSITORY) |
  .source.revision = strenv(SOURCE_REF) |
  .source.version = strenv(VERSION) |
  .source.configRevision = strenv(CONFIG_SHA) |
  .source.toolingRevision = strenv(TOOLING_SHA)
' "$file"

if git diff --quiet; then
  echo "Digest không đổi, không cần PR"
  exit 0
fi

git config user.name "ol-automation[bot]"
git config user.email "ol-automation[bot]@users.noreply.github.com"
git add "$file"
git commit -q -m "deploy($DEPLOY_ENV): $MODULE ${VERSION} (${SOURCE_REF:0:7})"
git push -q origin "$branch"

body=$(cat <<EOF
Cập nhật **$MODULE** ở môi trường **$DEPLOY_ENV**.

| | |
|---|---|
| Image digest | \`$DIGEST\` |
| Source | $SOURCE_REPOSITORY@\`$SOURCE_REF\` (v$VERSION) |
| Build config (ol-infra) | \`$CONFIG_SHA\` |
| Dockerfile (ol-build-tooling) | \`$TOOLING_SHA\` |

Xác minh nguồn gốc image: \`gh attestation verify oci://<registry>/ol/$MODULE@$DIGEST --owner $OWNER\`
EOF
)
url=$(gh pr create --title "deploy($DEPLOY_ENV): $MODULE ${SOURCE_REF:0:7}" --body "$body" --base main --head "$branch")
echo "PR: $url"

if [[ "$DEPLOY_ENV" != "prod" ]]; then
  gh pr merge "$url" --auto --squash   # Tự merge khi mọi required check của ol-infra xanh
fi
