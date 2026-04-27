#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_FILE="${CONFIG_FILE:-${BACKUP_S3_CONFIG:-$CONFIG_FILE_DEFAULT}}"

set_config_defaults() {
    APP_NAME="${APP_NAME:-Backup-S3}"
    APP_VERSION="${APP_VERSION:-1.0.0}"
    BACKUP_PROFILE_NAME="${BACKUP_PROFILE_NAME:-default}"
    SITE_NAME="${SITE_NAME:-}"
    SITE_DIR="${SITE_DIR:-}"
    DB_ENABLED="${DB_ENABLED:-true}"
    DB_TYPE="${DB_TYPE:-mysql}"
    DB_NAME="${DB_NAME:-}"
    DB_USER="${DB_USER:-}"
    DB_PASS="${DB_PASS:-}"
    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-3306}"
    S3_PROVIDER="${S3_PROVIDER:-yandex}"
    S3_ENDPOINT="${S3_ENDPOINT:-https://storage.yandexcloud.net}"
    S3_BUCKET="${S3_BUCKET:-}"
    S3_PREFIX="${S3_PREFIX:-}"
    S3_STORAGE_CLASS="${S3_STORAGE_CLASS:-COLD}"
    S3_REGION="${S3_REGION:-ru-central1}"
    S3_ACCESS_KEY_ID="${S3_ACCESS_KEY_ID:-}"
    S3_SECRET_ACCESS_KEY="${S3_SECRET_ACCESS_KEY:-}"
    BACKUP_ROOT="${BACKUP_ROOT:-/opt/backup-s3}"
    LOG_DIR="${LOG_DIR:-/var/log/backup-s3}"
    STATE_DIR="${STATE_DIR:-/var/lib/backup-s3}"
    RUNTIME_DIR="${RUNTIME_DIR:-/var/run/backup-s3}"
    LOCAL_RETENTION_DAYS="${LOCAL_RETENTION_DAYS:-3}"
    MIN_FREE_SPACE_PERCENT="${MIN_FREE_SPACE_PERCENT:-15}"
    DRY_RUN="${DRY_RUN:-false}"
    DEBUG="${DEBUG:-false}"
    ENCRYPT_BACKUP="${ENCRYPT_BACKUP:-false}"
    ENCRYPTION_METHOD="${ENCRYPTION_METHOD:-openssl}"
    ENCRYPTION_PASSWORD_FILE="${ENCRYPTION_PASSWORD_FILE:-/etc/backup-s3/encryption.key}"
    MAINTENANCE_MODE="${MAINTENANCE_MODE:-false}"
    PRE_BACKUP_COMMAND="${PRE_BACKUP_COMMAND:-}"
    POST_BACKUP_COMMAND="${POST_BACKUP_COMMAND:-}"
    EXTRA_PATHS="${EXTRA_PATHS:-}"
    EXCLUDE_PATHS="${EXCLUDE_PATHS:-cache,tmp,logs,log,node_modules,vendor,.git,bitrix/cache,bitrix/managed_cache,bitrix/stack_cache,upload/resize_cache}"
    VERIFY_UPLOAD="${VERIFY_UPLOAD:-true}"
    CHECK_REMOTE_AFTER_UPLOAD="${CHECK_REMOTE_AFTER_UPLOAD:-true}"
    PROGRESS_MODE="${PROGRESS_MODE:-auto}"
    TUI_BACKEND="${TUI_BACKEND:-auto}"
    SYSTEMD_TIMER_TIME="${SYSTEMD_TIMER_TIME:-03:30:00}"
}

load_config() {
    local config_file="${1:-$CONFIG_FILE}"
    CONFIG_FILE="$config_file"
    if [ ! -f "$config_file" ]; then
        echo "Ошибка: файл конфигурации не найден: $config_file" >&2
        echo "Создайте его из примера: sudo cp /etc/backup-s3/backup-s3.env.example $config_file" >&2
        return "$EXIT_CONFIG"
    fi
    set -a
    # shellcheck disable=SC1090
    . "$config_file"
    set +a
    set_config_defaults
}

check_config_permissions() {
    local config_file="${1:-$CONFIG_FILE}"
    if [ ! -f "$config_file" ]; then
        echo "Ошибка: файл конфигурации не найден: $config_file" >&2
        return "$EXIT_CONFIG"
    fi
    local mode
    mode="$(stat -c '%a' "$config_file" 2>/dev/null || echo "unknown")"
    if [ "$mode" != "600" ] && [ "$mode" != "400" ]; then
        echo "Предупреждение: файл конфигурации имеет небезопасные права ($mode)." >&2
        echo "Исправьте: sudo chmod 600 $config_file" >&2
        return "$EXIT_CONFIG"
    fi
}

fix_config_permissions() {
    local config_file="${1:-$CONFIG_FILE}"
    chmod 600 "$config_file"
    echo "Права файла конфигурации исправлены: chmod 600 $config_file"
}

derive_s3_prefix() {
    if [ -n "${S3_PREFIX:-}" ]; then
        printf '%s' "$S3_PREFIX"
    elif [ -n "${SITE_NAME:-}" ]; then
        printf '%s' "$(sanitize_name "$SITE_NAME")"
    else
        printf '%s' "$(sanitize_name "${BACKUP_PROFILE_NAME:-default}")"
    fi
}

backup_stamp() {
    printf '%s' "${BACKUP_TS:-$(timestamp)}"
}

backup_s3_dir() {
    local ts="${1:-$(backup_stamp)}"
    local prefix
    prefix="$(derive_s3_prefix)"
    if [ -n "$prefix" ]; then
        printf 's3://%s/%s/%s/' "$S3_BUCKET" "${prefix%/}" "$ts"
    else
        printf 's3://%s/%s/' "$S3_BUCKET" "$ts"
    fi
}

validate_required_config() {
    local errors=0
    if [ -z "${SITE_DIR:-}" ]; then
        echo "Ошибка: SITE_DIR не задан. Укажите директорию сайта или проекта." >&2
        errors=1
    elif [ ! -d "$SITE_DIR" ]; then
        echo "Ошибка: SITE_DIR не существует: $SITE_DIR" >&2
        errors=1
    fi
    if bool_true "$DB_ENABLED"; then
        if [ -z "${DB_NAME:-}" ]; then
            echo "Ошибка: DB_NAME пустой при DB_ENABLED=true." >&2
            errors=1
        fi
        if [ -z "${DB_USER:-}" ]; then
            echo "Ошибка: DB_USER пустой при DB_ENABLED=true." >&2
            errors=1
        fi
        case "$DB_TYPE" in
            mysql|mariadb|postgres) ;;
            *)
                echo "Ошибка: DB_TYPE должен быть mysql, mariadb или postgres." >&2
                errors=1
                ;;
        esac
    fi
    if [ -z "${S3_BUCKET:-}" ]; then
        echo "Ошибка: S3_BUCKET не задан." >&2
        errors=1
    fi
    if [ -z "${S3_ENDPOINT:-}" ]; then
        echo "Ошибка: S3_ENDPOINT не задан." >&2
        errors=1
    fi
    if [ -z "${S3_ACCESS_KEY_ID:-}" ]; then
        echo "Ошибка: S3_ACCESS_KEY_ID не задан." >&2
        errors=1
    fi
    if [ -z "${S3_SECRET_ACCESS_KEY:-}" ]; then
        echo "Ошибка: S3_SECRET_ACCESS_KEY не задан." >&2
        errors=1
    fi
    if [ "$errors" -ne 0 ]; then
        return "$EXIT_CONFIG"
    fi
}

show_effective_config_masked() {
    cat <<EOF
APP_NAME="${APP_NAME}"
APP_VERSION="${APP_VERSION}"
BACKUP_PROFILE_NAME="${BACKUP_PROFILE_NAME}"
SITE_NAME="${SITE_NAME}"
SITE_DIR="${SITE_DIR}"
DB_ENABLED="${DB_ENABLED}"
DB_TYPE="${DB_TYPE}"
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASS="$(mask_value "${DB_PASS:-}")"
DB_HOST="${DB_HOST}"
DB_PORT="${DB_PORT}"
S3_PROVIDER="${S3_PROVIDER}"
S3_ENDPOINT="${S3_ENDPOINT}"
S3_BUCKET="${S3_BUCKET}"
S3_PREFIX="$(derive_s3_prefix)"
S3_STORAGE_CLASS="${S3_STORAGE_CLASS}"
S3_REGION="${S3_REGION}"
S3_ACCESS_KEY_ID="$(mask_value "${S3_ACCESS_KEY_ID:-}")"
S3_SECRET_ACCESS_KEY="$(mask_value "${S3_SECRET_ACCESS_KEY:-}")"
BACKUP_ROOT="${BACKUP_ROOT}"
LOG_DIR="${LOG_DIR}"
STATE_DIR="${STATE_DIR}"
RUNTIME_DIR="${RUNTIME_DIR}"
LOCAL_RETENTION_DAYS="${LOCAL_RETENTION_DAYS}"
MIN_FREE_SPACE_PERCENT="${MIN_FREE_SPACE_PERCENT}"
DRY_RUN="${DRY_RUN}"
ENCRYPT_BACKUP="${ENCRYPT_BACKUP}"
EXTRA_PATHS="${EXTRA_PATHS}"
EXCLUDE_PATHS="${EXCLUDE_PATHS}"
VERIFY_UPLOAD="${VERIFY_UPLOAD}"
CHECK_REMOTE_AFTER_UPLOAD="${CHECK_REMOTE_AFTER_UPLOAD}"
SYSTEMD_TIMER_TIME="${SYSTEMD_TIMER_TIME}"
EOF
}
