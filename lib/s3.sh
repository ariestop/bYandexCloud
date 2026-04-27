#!/usr/bin/env bash
set -Eeuo pipefail

aws_base_args() {
    printf '%s\n' "--endpoint-url"
    printf '%s\n' "$S3_ENDPOINT"
    printf '%s\n' "--region"
    printf '%s\n' "$S3_REGION"
}

aws_cli() {
    local args=()
    while IFS= read -r item; do
        args+=("$item")
    done < <(aws_base_args)
    with_aws_env aws "${args[@]}" "$@"
}

check_s3_access() {
    if ! command_exists aws; then
        echo "Не найден aws cli. Установите: pip3 install awscli" >&2
        return "$EXIT_DEPENDENCY"
    fi
    if ! aws_cli s3 ls "s3://${S3_BUCKET}" >/dev/null 2>&1; then
        echo "Нет доступа к bucket. Проверьте S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, S3_BUCKET и права сервисного аккаунта." >&2
        return "$EXIT_S3"
    fi
}

check_s3_write_delete() {
    local test_key
    test_key="$(derive_s3_prefix)/healthcheck_$(timestamp)_$$.txt"
    local tmp
    tmp="$(mktemp)"
    echo "Backup-S3 health-check $(iso_now)" > "$tmp"
    if ! aws_cli s3 cp "$tmp" "s3://${S3_BUCKET}/${test_key}" >/dev/null 2>&1; then
        rm -f "$tmp"
        echo "Не удалось записать тестовый объект в S3 bucket." >&2
        return "$EXIT_S3"
    fi
    aws_cli s3 rm "s3://${S3_BUCKET}/${test_key}" >/dev/null 2>&1 || true
    rm -f "$tmp"
    echo "Проверка записи и удаления в S3 выполнена успешно."
}

s3_object_target() {
    local file="$1"
    local base_target="${CURRENT_S3_TARGET:-$(backup_s3_dir)}"
    printf '%s%s' "$base_target" "$(basename "$file")"
}

upload_file_to_s3() {
    local file="$1"
    local target
    target="$(s3_object_target "$file")"
    local size
    size="$(file_size "$file")"
    log_info "Загрузка в S3: $(basename "$file") -> $target"
    set_operation_progress "S3 upload: $(basename "$file")" 0 "$size" "" ""

    if bool_true "${DRY_RUN:-false}"; then
        log_info "[dry-run] Файл не загружается: $target"
        return 0
    fi

    if command_exists pv && [ "$size" -gt 0 ] && [ "${PROGRESS_MODE:-auto}" != "off" ]; then
        pv -f -s "$size" -N "S3 UPLOAD" "$file" | aws_cli s3 cp - "$target" --expected-size "$size" --storage-class "$S3_STORAGE_CLASS"
    else
        aws_cli s3 cp "$file" "$target" --storage-class "$S3_STORAGE_CLASS"
    fi
    log_success "Файл загружен: $target"
}

upload_files_to_s3() {
    local file
    for file in "$@"; do
        [ -f "$file" ] || continue
        upload_file_to_s3 "$file"
    done
}

verify_remote_files() {
    if ! bool_true "${VERIFY_UPLOAD:-true}"; then
        log_warn "Проверка загрузки отключена VERIFY_UPLOAD=false."
        return 0
    fi
    if bool_true "${DRY_RUN:-false}"; then
        log_info "[dry-run] Проверка файлов в S3 пропущена."
        return 0
    fi
    local file target
    for file in "$@"; do
        [ -f "$file" ] || continue
        target="$(s3_object_target "$file")"
        if ! aws_cli s3 ls "$target" >/dev/null 2>&1; then
            log_error "Файл не найден в S3 после загрузки: $target"
            return "$EXIT_UPLOAD"
        fi
    done
    log_success "Проверка наличия файлов в S3 выполнена успешно."
}

list_remote_backups() {
    load_config
    local prefix
    prefix="$(derive_s3_prefix)"
    echo "Список объектов в s3://${S3_BUCKET}/${prefix}/"
    aws_cli s3 ls "s3://${S3_BUCKET}/${prefix}/" --recursive || {
        echo "Не удалось получить список удалённых бэкапов." >&2
        return "$EXIT_S3"
    }
}
