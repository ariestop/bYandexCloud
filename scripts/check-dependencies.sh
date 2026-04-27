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
. "$ROOT/lib/checks.sh"

load_config 2>/dev/null || set_config_defaults
check_dependencies
