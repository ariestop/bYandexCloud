#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/logger.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/config.sh"

S3_BUCKET="my-bucket"
SITE_NAME="site.example"
BACKUP_PROFILE_NAME="default"
S3_PREFIX=""
[ "$(derive_s3_prefix)" = "site.example" ]
[ "$(backup_s3_dir "2026-04-27_03-30-00")" = "s3://my-bucket/site.example/2026-04-27_03-30-00/" ]

S3_PREFIX="custom/prefix"
[ "$(derive_s3_prefix)" = "custom/prefix" ]
[ "$(backup_s3_dir "2026-04-27_03-30-00")" = "s3://my-bucket/custom/prefix/2026-04-27_03-30-00/" ]

help_output="$("$ROOT/bin/backup-s3" --help)"
case "$help_output" in
    *"Backup-S3"*) ;;
    *) echo "help не содержит Backup-S3" >&2; exit 1 ;;
esac

grep -q '\*.env' "$ROOT/.gitignore"
grep -q '\*.log' "$ROOT/.gitignore"
grep -q '\*.tar.gz' "$ROOT/.gitignore"

echo "test-s3-target: OK"
