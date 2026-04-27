#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="${LOG_FILE:-}"

init_logging() {
    local profile="${BACKUP_PROFILE_NAME:-default}"
    local ts="${BACKUP_TS:-$(timestamp)}"
    LOG_DIR="${LOG_DIR:-/var/log/backup-s3}"
    ensure_dir "$LOG_DIR"
    LOG_FILE="${LOG_FILE:-${LOG_DIR}/${profile}_${ts}.log}"
    : > "$LOG_FILE"
}

mask_value() {
    local value="${1:-}"
    local len="${#value}"
    if [ "$len" -eq 0 ]; then
        printf ''
    elif [ "$len" -le 6 ]; then
        printf '******'
    else
        printf '%s********' "${value:0:3}"
    fi
}

mask_line() {
    local line="$1"
    case "$line" in
        DB_PASS=*|S3_SECRET_ACCESS_KEY=*|S3_ACCESS_KEY_ID=*|ENCRYPTION_PASSWORD_FILE=*)
            local key="${line%%=*}"
            local val="${line#*=}"
            val="${val%\"}"
            val="${val#\"}"
            printf '%s="%s"\n' "$key" "$(mask_value "$val")"
            ;;
        *)
            printf '%s\n' "$line"
            ;;
    esac
}

log_write() {
    local level="$1"
    shift
    local message="$*"
    local line
    line="$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
    echo "$line" >&2
    if [ -n "${LOG_FILE:-}" ]; then
        printf '%s\n' "$line" >> "$LOG_FILE"
    fi
}

log_info() { log_write "INFO" "$@"; }
log_warn() { log_write "WARN" "$@"; }
log_error() { log_write "ERROR" "$@"; }
log_success() { log_write "SUCCESS" "$@"; }
log_step() { log_write "STEP" "$@"; }

log_debug() {
    if bool_true "${DEBUG:-false}"; then
        log_write "DEBUG" "$@"
    fi
}

print_masked_config() {
    local config_file="${1:-${CONFIG_FILE:-}}"
    if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
        echo "Файл конфигурации не найден."
        return "$EXIT_CONFIG"
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) printf '%s\n' "$line" ;;
            *) mask_line "$line" ;;
        esac
    done < "$config_file"
}
