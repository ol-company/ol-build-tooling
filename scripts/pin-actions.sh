#!/usr/bin/env bash
# Thay "uses: owner/repo@vX" bằng "uses: owner/repo@<commit-sha> # vX" trong mọi workflow.
# Lý do: tag có thể bị dời (tấn công chuỗi cung ứng); SHA thì bất biến. Org đã bật chính sách bắt buộc pin SHA.
# Dùng: scripts/pin-actions.sh [thư-mục-workflows]   (cần gh đã đăng nhập)
# Action nội bộ của org (ol-company/ol-build-tooling/...@vX) cũng được pin; Dependabot sẽ cập nhật SHA + chú thích.
set -euo pipefail
dir="${1:-.github/workflows}"

resolve() { # owner/repo tag → sha của commit
  local repo="$1" tag="$2" sha type
  read -r sha type < <(gh api "repos/$repo/git/ref/tags/$tag" --jq '.object.sha + " " + .object.type')
  if [[ "$type" == "tag" ]]; then                     # Tag có chú thích → trỏ tới object tag, lấy commit bên trong
    sha=$(gh api "repos/$repo/git/tags/$sha" --jq '.object.sha')
  fi
  echo "$sha"
}

shopt -s nullglob
for f in "$dir"/*.yml "$dir"/*.yaml; do
  # Lấy các dòng "uses: owner/repo[/path]@ref" mà ref chưa phải SHA 40 ký tự
  grep -oE 'uses:[[:space:]]*[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[A-Za-z0-9_.-]+' "$f" | sed -E 's/uses:[[:space:]]*//' | sort -u | while read -r ref; do
    action="${ref%@*}"; tag="${ref##*@}"
    [[ "$tag" =~ ^[0-9a-f]{40}$ ]] && continue
    repo=$(echo "$action" | cut -d/ -f1-2)
    sha=$(resolve "$repo" "$tag")
    echo "$f: $action@$tag → $sha"
    # Thay đúng chuỗi, giữ lại tag dạng chú thích để người đọc biết version
    sed -i -E "s#(uses:[[:space:]]*)${action//./\\.}@${tag//./\\.}([[:space:]]|$)#\\1${action}@${sha} \\# ${tag}\\2#" "$f"
  done
done
