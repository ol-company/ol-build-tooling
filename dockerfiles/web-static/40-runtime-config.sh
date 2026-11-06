#!/bin/sh
# Chạy tự động khi container nginx khởi động (thư mục /docker-entrypoint.d/).
# Sinh /config.json từ biến môi trường → cùng một image chạy được ở mọi môi trường.
# CHỈ đưa giá trị công khai vào đây: trình duyệt đọc được toàn bộ file này.
set -eu

APP_ENV="${APP_ENV:-local}"
case "$APP_ENV" in
  local|dev|staging|prod) ;;                       # Chỉ chấp nhận giá trị đã biết
  *) echo "APP_ENV không hợp lệ: $APP_ENV" >&2; exit 1 ;;
esac
APP_NAME="${APP_NAME:-OL-Platform Admin}"
# Không cho ký tự có thể phá cấu trúc JSON
case "$APP_NAME" in *[\"\\]*) echo "APP_NAME chứa ký tự không hợp lệ" >&2; exit 1 ;; esac

mkdir -p /tmp/runtime                                # /tmp ghi được kể cả khi root filesystem chỉ đọc
printf '{"environment":"%s","appName":"%s"}\n' "$APP_ENV" "$APP_NAME" > /tmp/runtime/config.json
echo "runtime config: environment=$APP_ENV"
