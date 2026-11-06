#!/usr/bin/env bash
# Thay "uses: owner/repo@vX" bằng "uses: owner/repo@<commit-sha> # vX" trong mọi workflow.
# Lý do: tag có thể bị dời (tấn công chuỗi cung ứng); SHA thì bất biến. Org đã bật chính sách bắt buộc pin SHA.
# Dùng: scripts/pin-actions.sh [thư-mục-workflows]   (cần gh đã đăng nhập)
# Action nội bộ của org (ol-company/ol-build-tooling/...@vX) cũng được pin; Dependabot sẽ cập nhật SHA + chú thích.
#   → Tag nội bộ phải tồn tại TRƯỚC khi pin. Lần đầu: pin riêng ol-build-tooling, phát hành v1.0.0, rồi mới pin các repo còn lại.
# Gặp lỗi (tag không tồn tại, hết quyền, mất mạng...) script DỪNG ngay và không ghi gì vào file đó.
# Chỉ xử lý dòng "uses:" thật; dòng comment (vd "# Repo gọi: jobs.ci.uses: ...@vX") được bỏ qua.
set -euo pipefail
dir="${1:-.github/workflows}"

die() { echo "LỖI: $*" >&2; exit 1; }

resolve() { # owner/repo tag → sha của commit
  local repo="$1" tag="$2" out sha type
  # Gán qua $(...) || die (không dùng `read < <(gh ...)`): cách đó nuốt mất mã lỗi của gh,
  # khiến JSON báo lỗi 404 bị ghi nhầm vào workflow như thể là SHA.
  out=$(gh api "repos/$repo/git/ref/tags/$tag" --jq '.object.sha + " " + .object.type' </dev/null) \
    || die "không tìm thấy TAG '$tag' của $repo (branch như 'v4' không dùng được — hãy ghi tag đầy đủ như v4.9.0; tag nội bộ thì phải phát hành trước)"
  read -r sha type <<< "$out"
  if [[ "$type" == "tag" ]]; then                     # Tag có chú thích → trỏ tới object tag, lấy commit bên trong
    sha=$(gh api "repos/$repo/git/tags/$sha" --jq '.object.sha' </dev/null) || die "không đọc được annotated tag '$tag' của $repo"
  fi
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "kết quả không phải SHA 40 ký tự cho $repo@$tag: '$sha'"
  echo "$sha"
}

shopt -s nullglob
# Khóa "uses:" ở đầu dòng (có thể sau "- "), không phải nằm trong comment
key='[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*'
for f in "$dir"/*.yml "$dir"/*.yaml; do
  # Lấy các dòng "uses: owner/repo[/path]@ref" mà ref chưa phải SHA 40 ký tự.
  # Dùng < <(...) thay vì pipe: `exit` trong vòng lặp dừng cả script, và dòng không khớp không làm script chết do pipefail.
  while read -r ref; do
    action="${ref%@*}"; tag="${ref##*@}"
    if [[ "$tag" =~ ^[0-9a-f]{40}$ ]]; then continue; fi
    repo=$(echo "$action" | cut -d/ -f1-2)
    sha=$(resolve "$repo" "$tag")
    echo "$f: $action@$tag → $sha"
    # Thay đúng chuỗi (neo đầu dòng, không đụng comment), giữ lại tag dạng chú thích để người đọc biết version
    sed -i -E "s#^(${key})${action//./\\.}@${tag//./\\.}([[:space:]]|$)#\\1${action}@${sha} \\# ${tag}\\3#" "$f"
  done < <(grep -oE "^${key}[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[A-Za-z0-9_.-]+" "$f" | sed -E "s/^${key}//" | sort -u)
done
