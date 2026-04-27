#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_S3_CONFIG="${BACKUP_S3_CONFIG:-$ROOT/config/backup-s3.env.example}" "$ROOT/bin/backup-s3" --dry-run
