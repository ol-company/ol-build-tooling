#!/usr/bin/env bash
# Kiểm tra file build-config (ol-infra/build-config/<env>/<module>.env) trước khi build.
# Dùng: validate-build-config.sh <đường-dẫn-file>
# Thành công: in ra stdout các dòng KEY=VALUE hợp lệ (pipeline ghi vào $GITHUB_OUTPUT / build-args).
# Thất bại: thoát mã 1 với lý do — pipeline dừng, không build.
set -euo pipefail

file="${1:?Cần đường dẫn file build-config}"
[[ -f "$file" ]] || { echo "Không tìm thấy $file" >&2; exit 1; }

declare -A seen=()
errors=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"                                   # Bỏ CR nếu file bị lưu kiểu Windows
  [[ -z "${line// }" || "$line" =~ ^[[:space:]]*# ]] && continue   # Bỏ dòng trống và chú thích
  if [[ ! "$line" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
    echo "Dòng sai định dạng KEY=VALUE: $line" >&2; errors=$((errors+1)); continue
  fi
  key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"

  # 1) Chỉ cho phép các khóa đã biết
  case "$key" in
    DOCKERFILE|CONTEXT|INFRA_CONTEXT_PATH|BUILD_TARGET|BUILD_ARG_*) ;;
    *) echo "Khóa không được phép: $key" >&2; errors=$((errors+1)); continue ;;
  esac
  # 2) Không bao giờ chứa bí mật — bí mật build đi qua BuildKit secret, bí mật runtime đi qua Secrets Manager
  if [[ "$key" =~ (SECRET|PASSWORD|PASSWD|TOKEN|PRIVATE|CREDENTIAL|APIKEY|API_KEY) ]]; then
    echo "Khóa trông giống bí mật, không được đặt trong build-config: $key" >&2; errors=$((errors+1)); continue
  fi
  # 3) Giá trị không có ký tự nguy hiểm cho shell/YAML
  if [[ "$value" =~ [\$\`\"\'\\[:space:]] ]]; then
    echo "Giá trị của $key chứa ký tự không cho phép" >&2; errors=$((errors+1)); continue
  fi
  [[ -n "${seen[$key]:-}" ]] && { echo "Khóa lặp lại: $key" >&2; errors=$((errors+1)); continue; }
  seen[$key]=1
  echo "$key=$value"
done < "$file"

[[ -n "${seen[DOCKERFILE]:-}" ]] || { echo "Thiếu DOCKERFILE" >&2; errors=$((errors+1)); }
[[ -n "${seen[CONTEXT]:-}" ]] || { echo "Thiếu CONTEXT" >&2; errors=$((errors+1)); }
exit $(( errors > 0 ? 1 : 0 ))
