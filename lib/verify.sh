#!/usr/bin/env bash
set -Eeuo pipefail

find_latest_local_backup() {
    if [ ! -d "${BACKUP_ROOT:-/opt/backup-s3}" ]; then
        return 1
    fi
    find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {$1=""; sub(/^ /,""); print}'
}

verify_backup_dir() {
    local dir="$1"
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        echo "Директория бэкапа не найдена: $dir" >&2
        return "$EXIT_VERIFY"
    fi
    if [ ! -f "$dir/SHA256SUMS.txt" ]; then
        echo "Файл SHA256SUMS.txt не найден в $dir" >&2
        return "$EXIT_VERIFY"
    fi
    (
        cd "$dir"
        sha256sum -c SHA256SUMS.txt
    )
}

verify_last_local_backup() {
    load_config
    local dir
    dir="$(find_latest_local_backup || true)"
    if [ -z "$dir" ]; then
        echo "Локальные бэкапы не найдены в $BACKUP_ROOT."
        return "$EXIT_VERIFY"
    fi
    echo "Проверяется последний локальный бэкап: $dir"
    verify_backup_dir "$dir"
}

check_last_backup_freshness() {
    load_config
    local state
    state="$(state_file)"
    if [ ! -f "$state" ]; then
        echo "state.json не найден. Успешных запусков пока нет."
        return "$EXIT_VERIFY"
    fi
    local last_success
    last_success="$(sed -n 's/.*"last_success_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$state" | head -n 1 || true)"
    if [ -z "$last_success" ]; then
        echo "Последний успешный бэкап не найден."
        return "$EXIT_VERIFY"
    fi
    echo "Последний успешный бэкап: $last_success"
    echo "Файл состояния: $state"
}

list_local_backups() {
    load_config
    if [ ! -d "$BACKUP_ROOT" ]; then
        echo "Директория локальных бэкапов не найдена: $BACKUP_ROOT"
        return 0
    fi
    echo "Последние локальные бэкапы в $BACKUP_ROOT:"
    find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -r | head -n 20
}
