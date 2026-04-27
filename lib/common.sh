#!/usr/bin/env bash
set -Eeuo pipefail

export APP_NAME_DEFAULT="Backup-S3"
export APP_VERSION_DEFAULT="1.0.0"
export CONFIG_FILE_DEFAULT="/etc/backup-s3/backup-s3.env"
export INSTALL_LIB_DIR_DEFAULT="/usr/local/lib/backup-s3"

export EXIT_OK=0
export EXIT_GENERAL=1
export EXIT_CONFIG=2
export EXIT_DEPENDENCY=3
export EXIT_DB=4
export EXIT_S3=5
export EXIT_SPACE=6
export EXIT_LOCKED=7
export EXIT_ARCHIVE=8
export EXIT_UPLOAD=9
export EXIT_VERIFY=10

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

is_root() {
    [ "${EUID:-$(id -u)}" -eq 0 ]
}

require_root() {
    if [ "${BACKUP_S3_ALLOW_NON_ROOT:-false}" = "true" ]; then
        return 0
    fi
    if ! is_root; then
        echo "Ошибка: для этой операции нужны права root. Запустите команду через sudo." >&2
        exit "$EXIT_GENERAL"
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_dir() {
    local dir="$1"
    if [ -z "$dir" ] || [ "$dir" = "/" ]; then
        echo "Ошибка: отказ создать небезопасный путь: '$dir'" >&2
        return "$EXIT_CONFIG"
    fi
    mkdir -p "$dir"
}

safe_rm_dir_children_older_than() {
    local root="$1"
    local days="$2"

    if [ -z "$root" ] || [ "$root" = "/" ] || [ ! -d "$root" ]; then
        echo "Ошибка: отказ удалять файлы в небезопасном пути: '$root'" >&2
        return "$EXIT_CONFIG"
    fi
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then
        echo "Ошибка: LOCAL_RETENTION_DAYS должен быть числом." >&2
        return "$EXIT_CONFIG"
    fi

    find "$root" -mindepth 1 -maxdepth 1 -type d -mtime +"$days" -print0 | while IFS= read -r -d '' dir; do
        case "$dir" in
            "$root"/*) rm -rf -- "$dir" ;;
            *) echo "Предупреждение: пропущен небезопасный путь очистки: $dir" >&2 ;;
        esac
    done
}

timestamp() {
    date '+%Y-%m-%d_%H-%M-%S'
}

iso_now() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

human_bytes() {
    local bytes="${1:-0}"
    if command_exists numfmt; then
        numfmt --to=iec --suffix=B "$bytes" 2>/dev/null || printf '%s B' "$bytes"
    else
        printf '%s B' "$bytes"
    fi
}

file_size() {
    local file="$1"
    if stat -c '%s' "$file" >/dev/null 2>&1; then
        stat -c '%s' "$file"
    else
        wc -c < "$file" | tr -d ' '
    fi
}

dir_size_bytes() {
    local dir="$1"
    if command_exists du; then
        du -sb "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo 0
    fi
}

json_escape() {
    local value="${1:-}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    printf '%s' "$value"
}

bool_true() {
    case "${1:-}" in
        true|TRUE|1|yes|YES|y|Y|да|ДА) return 0 ;;
        *) return 1 ;;
    esac
}

sanitize_name() {
    local value="${1:-backup}"
    value="${value// /_}"
    value="${value//\//_}"
    value="${value//:/_}"
    printf '%s' "$value" | tr -cd 'A-Za-z0-9._-'
}

resolve_lib_dir() {
    if [ -n "${BACKUP_S3_LIB_DIR:-}" ] && [ -d "$BACKUP_S3_LIB_DIR" ]; then
        printf '%s' "$BACKUP_S3_LIB_DIR"
    elif [ -d "$PROJECT_ROOT/lib" ]; then
        printf '%s' "$PROJECT_ROOT/lib"
    else
        printf '%s' "$INSTALL_LIB_DIR_DEFAULT"
    fi
}

print_version() {
    echo "${APP_NAME:-$APP_NAME_DEFAULT} ${APP_VERSION:-$APP_VERSION_DEFAULT}"
}
