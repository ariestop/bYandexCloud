#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck не установлен."
    echo "CentOS/RHEL: sudo yum install -y epel-release shellcheck"
    echo "Debian/Ubuntu: sudo apt-get install -y shellcheck"
    exit 3
fi

shellcheck scripts/*.sh lib/*.sh bin/backup-s3 tests/*.sh
