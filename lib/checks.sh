#!/usr/bin/env bash
set -Eeuo pipefail

check_dependency() {
    local cmd="$1"
    local required="${2:-true}"
    if command_exists "$cmd"; then
        echo "OK: найдено $cmd"
        return 0
    fi
    if bool_true "$required"; then
        echo "Ошибка: не найдено $cmd" >&2
        return "$EXIT_DEPENDENCY"
    fi
    echo "Предупреждение: не найдено $cmd (необязательная зависимость)." >&2
    return 0
}

check_dependencies() {
    local rc=0
    check_dependency tar true || rc=$?
    check_dependency gzip true || rc=$?
    check_dependency find true || rc=$?
    check_dependency sha256sum true || rc=$?
    check_dependency awk true || rc=$?
    check_dependency sed true || rc=$?
    check_dependency aws true || rc=$?
    check_dependency pv false || true
    check_dependency jq false || true
    check_dependency dialog false || true
    check_dependency whiptail false || true
    if bool_true "${DB_ENABLED:-false}"; then
        case "${DB_TYPE:-mysql}" in
            mysql|mariadb)
                if ! command_exists mysqldump && ! command_exists mariadb-dump; then
                    echo "Ошибка: не найден mysqldump или mariadb-dump." >&2
                    rc="$EXIT_DEPENDENCY"
                fi
                if ! command_exists mysql && ! command_exists mariadb; then
                    echo "Ошибка: не найден mysql или mariadb client." >&2
                    rc="$EXIT_DEPENDENCY"
                fi
                ;;
            postgres)
                check_dependency pg_dump true || rc=$?
                check_dependency psql true || rc=$?
                ;;
        esac
    fi
    return "$rc"
}

check_writable_dirs() {
    local dir
    for dir in "$BACKUP_ROOT" "$LOG_DIR" "$STATE_DIR" "$RUNTIME_DIR"; do
        ensure_dir "$dir"
        if [ ! -w "$dir" ]; then
            echo "Ошибка: нет прав на запись в $dir" >&2
            return "$EXIT_CONFIG"
        fi
    done
}

check_free_space() {
    ensure_dir "$BACKUP_ROOT"
    local available_percent
    available_percent="$(df -P "$BACKUP_ROOT" | awk 'NR==2 {gsub("%","",$5); print 100-$5}')"
    if [ -z "$available_percent" ]; then
        echo "Ошибка: не удалось проверить свободное место." >&2
        return "$EXIT_SPACE"
    fi
    if [ "$available_percent" -lt "${MIN_FREE_SPACE_PERCENT:-15}" ]; then
        echo "Недостаточно свободного места в $BACKUP_ROOT: доступно ${available_percent}%, минимум ${MIN_FREE_SPACE_PERCENT}%." >&2
        echo "Освободите место или увеличьте BACKUP_ROOT." >&2
        df -h "$BACKUP_ROOT" >&2
        return "$EXIT_SPACE"
    fi
    echo "Свободное место: ${available_percent}% (минимум ${MIN_FREE_SPACE_PERCENT}%)."
}

estimate_required_space() {
    local site_size=0
    [ -d "${SITE_DIR:-}" ] && site_size="$(dir_size_bytes "$SITE_DIR")"
    echo "Оценочный размер SITE_DIR: $(human_bytes "$site_size"). Для сжатия и временных файлов нужен запас."
}

check_database_access() {
    if ! bool_true "${DB_ENABLED:-false}"; then
        echo "Бэкап БД отключён DB_ENABLED=false."
        return 0
    fi
    case "${DB_TYPE:-mysql}" in
        mysql|mariadb) check_mysql_access ;;
        postgres) check_postgres_access ;;
        *) echo "Неподдерживаемый DB_TYPE: $DB_TYPE" >&2; return "$EXIT_CONFIG" ;;
    esac
}

run_health_check() {
    load_config
    echo "Проверка конфигурации: $CONFIG_FILE"
    check_config_permissions "$CONFIG_FILE" || return "$EXIT_CONFIG"
    validate_required_config
    check_writable_dirs
    check_dependencies
    check_free_space
    estimate_required_space
    check_database_access
    check_s3_access
    check_s3_write_delete
    echo "Все основные проверки успешно выполнены."
}

dry_run_report() {
    load_config
    echo "Тестовый режим Backup-S3: реальные архивы и загрузка в облако не выполняются."
    echo
    show_effective_config_masked
    echo
    echo "Будет архивироваться SITE_DIR: ${SITE_DIR:-не задано}"
    echo "Будет создаваться дамп БД: ${DB_ENABLED} (${DB_TYPE}, ${DB_NAME:-не задано})"
    echo "Исключения: ${EXCLUDE_PATHS:-не заданы}"
    echo "Дополнительные пути: ${EXTRA_PATHS:-не заданы}"
    echo "Целевой bucket: s3://${S3_BUCKET:-не задано}/"
    echo "Целевой prefix: $(derive_s3_prefix)"
    echo "Пример S3 target: $(backup_s3_dir "$(timestamp)")"
}
