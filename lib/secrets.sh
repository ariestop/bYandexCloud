#!/usr/bin/env bash
set -Eeuo pipefail

with_aws_env() {
    AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$S3_SECRET_ACCESS_KEY" \
    AWS_DEFAULT_REGION="$S3_REGION" \
    "$@"
}

create_mysql_defaults_file() {
    local tmp
    tmp="$(mktemp)"
    chmod 600 "$tmp"
    {
        echo "[client]"
        printf 'user=%s\n' "$DB_USER"
        printf 'password=%s\n' "$DB_PASS"
        printf 'host=%s\n' "$DB_HOST"
        printf 'port=%s\n' "$DB_PORT"
    } > "$tmp"
    printf '%s' "$tmp"
}

encrypt_file_if_needed() {
    local file="$1"
    if ! bool_true "${ENCRYPT_BACKUP:-false}"; then
        printf '%s' "$file"
        return 0
    fi
    if [ "${ENCRYPTION_METHOD:-openssl}" != "openssl" ]; then
        log_error "Поддерживается только ENCRYPTION_METHOD=openssl."
        return "$EXIT_CONFIG"
    fi
    if [ ! -f "${ENCRYPTION_PASSWORD_FILE:-}" ]; then
        log_error "Файл пароля шифрования не найден: ${ENCRYPTION_PASSWORD_FILE:-}"
        return "$EXIT_CONFIG"
    fi
    local out="${file}.enc"
    openssl enc -aes-256-cbc -salt -pbkdf2 -pass "file:${ENCRYPTION_PASSWORD_FILE}" -in "$file" -out "$out"
    chmod 600 "$out"
    printf '%s' "$out"
}
