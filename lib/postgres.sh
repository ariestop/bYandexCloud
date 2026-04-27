#!/usr/bin/env bash
set -Eeuo pipefail

check_postgres_access() {
    if ! command_exists psql; then
        echo "Не найден psql. Установите PostgreSQL client." >&2
        return "$EXIT_DEPENDENCY"
    fi
    PGPASSWORD="${DB_PASS:-}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1 || {
        echo "Нет доступа к PostgreSQL. Проверьте DB_USER, DB_PASS, DB_HOST, DB_PORT и права пользователя." >&2
        return "$EXIT_DB"
    }
}

dump_postgres_database() {
    local backup_dir="$1"
    local ts="$2"
    if ! command_exists pg_dump; then
        echo "Не найден pg_dump. Установите PostgreSQL client." >&2
        return "$EXIT_DEPENDENCY"
    fi
    local safe_db
    safe_db="$(sanitize_name "$DB_NAME")"
    local output="${backup_dir}/${safe_db}_${ts}.sql.gz"
    log_info "Создаётся дамп PostgreSQL базы '${DB_NAME}' в файл: $output"
    PGPASSWORD="${DB_PASS:-}" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" | gzip -c > "$output"
    chmod 600 "$output"
    log_success "Дамп PostgreSQL создан: $output ($(human_bytes "$(file_size "$output")"))"
    printf '%s' "$output"
}
