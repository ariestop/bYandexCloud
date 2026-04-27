#!/usr/bin/env bash
set -Eeuo pipefail

mysql_client_cmd() {
    if command_exists mysql; then
        printf 'mysql'
    elif command_exists mariadb; then
        printf 'mariadb'
    else
        return "$EXIT_DEPENDENCY"
    fi
}

mysqldump_cmd() {
    if command_exists mysqldump; then
        printf 'mysqldump'
    elif command_exists mariadb-dump; then
        printf 'mariadb-dump'
    else
        return "$EXIT_DEPENDENCY"
    fi
}

estimate_mysql_db_size() {
    local mysql_cmd
    mysql_cmd="$(mysql_client_cmd)"
    "$mysql_cmd" \
        --user="$DB_USER" --password="$DB_PASS" --host="$DB_HOST" --port="$DB_PORT" \
        --batch --skip-column-names -e \
        "SELECT COALESCE(SUM(data_length + index_length),0) FROM information_schema.tables WHERE table_schema='${DB_NAME//\'/\'\'}';" 2>/dev/null || echo 0
}

check_mysql_access() {
    local mysql_cmd
    mysql_cmd="$(mysql_client_cmd)"
    if ! "$mysql_cmd" \
        --user="$DB_USER" --password="$DB_PASS" --host="$DB_HOST" --port="$DB_PORT" \
        --batch --skip-column-names -e "SELECT 1;" "$DB_NAME" >/dev/null 2>&1; then
        echo "Нет доступа к MySQL/MariaDB. Проверьте DB_USER, DB_PASS, DB_HOST, DB_PORT и права пользователя." >&2
        return "$EXIT_DB"
    fi
}

dump_mysql_database() {
    local backup_dir="$1"
    local ts="$2"
    local safe_db
    safe_db="$(sanitize_name "$DB_NAME")"
    local output="${backup_dir}/${safe_db}_${ts}.sql.gz"
    local dump_cmd
    dump_cmd="$(mysqldump_cmd)"
    local estimated_size
    estimated_size="$(estimate_mysql_db_size)"
    [ -n "$estimated_size" ] || estimated_size=0

    log_info "Создаётся дамп MySQL/MariaDB базы '${DB_NAME}' в файл: $output"
    set_operation_progress "Дамп БД" 0 "$estimated_size" "" ""

    if command_exists pv && [ "$estimated_size" -gt 0 ] && [ "${PROGRESS_MODE:-auto}" != "off" ]; then
        "$dump_cmd" \
            --user="$DB_USER" --password="$DB_PASS" --host="$DB_HOST" --port="$DB_PORT" \
            --single-transaction --quick --routines --triggers --events "$DB_NAME" \
            | pv -f -s "$estimated_size" -N "DB DUMP" \
            | gzip -c > "$output"
    else
        "$dump_cmd" \
            --user="$DB_USER" --password="$DB_PASS" --host="$DB_HOST" --port="$DB_PORT" \
            --single-transaction --quick --routines --triggers --events "$DB_NAME" \
            | gzip -c > "$output"
    fi
    chmod 600 "$output"
    monitor_file_size_once "Дамп БД" "$output" "$estimated_size"
    log_success "Дамп БД создан: $output ($(human_bytes "$(file_size "$output")"))"
    printf '%s' "$output"
}
