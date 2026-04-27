#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/logger.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/config.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/status.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SITE_NAME="example.com"
BACKUP_PROFILE_NAME="default"
S3_BUCKET="bucket"
S3_PREFIX=""
STATE_DIR="$TMP_DIR/state"
RUNTIME_DIR="$TMP_DIR/run"

target="$(backup_s3_dir "2026-04-27_03-30-00")"
[ "$target" = "s3://bucket/example.com/2026-04-27_03-30-00/" ]

[ "$(sanitize_name "a/b:c d")" = "a_b_c_d" ]

ensure_state_dirs
write_status "running" "Тест" 1 2 50 "Операция" "10%" 1 10 "" "" ""
[ -f "$RUNTIME_DIR/status.json" ]
grep -q '"status": "running"' "$RUNTIME_DIR/status.json"

mkdir -p "$TMP_DIR/root/old"
safe_rm_dir_children_older_than "$TMP_DIR/root" 0 >/dev/null || true
[ -d "$TMP_DIR/root" ]

echo "test-functions: OK"
