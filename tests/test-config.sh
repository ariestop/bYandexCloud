#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/site" "$TMP_DIR/backup" "$TMP_DIR/log" "$TMP_DIR/state" "$TMP_DIR/run"
CONFIG="$TMP_DIR/backup-s3.env"
cat > "$CONFIG" <<EOF
APP_NAME="Backup-S3"
APP_VERSION="1.0.0"
BACKUP_PROFILE_NAME="test"
SITE_NAME="test-site"
SITE_DIR="$TMP_DIR/site"
DB_ENABLED="false"
DB_TYPE="mysql"
DB_NAME=""
DB_USER=""
DB_PASS=""
DB_HOST="localhost"
DB_PORT="3306"
S3_PROVIDER="test"
S3_ENDPOINT="https://example.invalid"
S3_BUCKET="test-bucket"
S3_PREFIX=""
S3_STORAGE_CLASS="COLD"
S3_REGION="ru-central1"
S3_ACCESS_KEY_ID="TESTACCESSKEY"
S3_SECRET_ACCESS_KEY="TESTSECRETKEY"
BACKUP_ROOT="$TMP_DIR/backup"
LOG_DIR="$TMP_DIR/log"
STATE_DIR="$TMP_DIR/state"
RUNTIME_DIR="$TMP_DIR/run"
LOCAL_RETENTION_DAYS="3"
MIN_FREE_SPACE_PERCENT="1"
DRY_RUN="false"
DEBUG="false"
ENCRYPT_BACKUP="false"
EXTRA_PATHS=""
EXCLUDE_PATHS="cache,tmp"
VERIFY_UPLOAD="true"
CHECK_REMOTE_AFTER_UPLOAD="true"
PROGRESS_MODE="off"
TUI_BACKEND="fallback"
SYSTEMD_TIMER_TIME="03:30:00"
EOF
chmod 600 "$CONFIG"

dry_run_output="$(BACKUP_S3_ALLOW_NON_ROOT=true BACKUP_S3_CONFIG="$CONFIG" "$ROOT/bin/backup-s3" --dry-run)"
case "$dry_run_output" in
    *"Тестовый режим Backup-S3"*) ;;
    *) echo "dry-run не содержит ожидаемый текст" >&2; exit 1 ;;
esac

config_output="$(BACKUP_S3_ALLOW_NON_ROOT=true BACKUP_S3_CONFIG="$CONFIG" "$ROOT/bin/backup-s3" --show-config)"
case "$config_output" in
    *'S3_SECRET_ACCESS_KEY="TES'*) ;;
    *) echo "секрет S3 не замаскирован" >&2; exit 1 ;;
esac
echo "test-config: OK"
