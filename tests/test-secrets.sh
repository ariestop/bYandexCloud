#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/logger.sh"

[ "$(mask_value "SECRET123456")" = "SEC********" ]
[ "$(mask_value "")" = "" ]
masked="$(mask_line 'DB_PASS="SUPERSECRET"')"
case "$masked" in
    DB_PASS=\"SUP********\") ;;
    *) echo "Секрет не замаскирован: $masked" >&2; exit 1 ;;
esac

echo "test-secrets: OK"
