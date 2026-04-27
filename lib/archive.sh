#!/usr/bin/env bash
set -Eeuo pipefail

build_tar_excludes() {
    local IFS=','
    local item
    for item in ${EXCLUDE_PATHS:-}; do
        item="$(printf '%s' "$item" | sed 's/^ *//;s/ *$//')"
        [ -n "$item" ] && printf -- '--exclude=%s\n' "$item"
    done
}

create_site_archive() {
    local backup_dir="$1"
    local ts="$2"
    local site_label
    site_label="$(sanitize_name "${SITE_NAME:-site}")"
    local output="${backup_dir}/${site_label}_files_${ts}.tar.gz"
    local parent
    parent="$(dirname "$SITE_DIR")"
    local base
    base="$(basename "$SITE_DIR")"
    local estimated_size
    estimated_size="$(dir_size_bytes "$SITE_DIR")"
    [ -n "$estimated_size" ] || estimated_size=0

    log_info "Архивируется директория сайта: $SITE_DIR"
    set_operation_progress "Архив сайта" 0 "$estimated_size" "" ""

    local exclude_args=()
    while IFS= read -r line; do
        [ -n "$line" ] && exclude_args+=("$line")
    done < <(build_tar_excludes)

    if command_exists pv && [ "$estimated_size" -gt 0 ] && [ "${PROGRESS_MODE:-auto}" != "off" ]; then
        tar -C "$parent" "${exclude_args[@]}" -cf - "$base" | pv -f -s "$estimated_size" -N "SITE ARCHIVE" | gzip -c > "$output"
    else
        tar -C "$parent" "${exclude_args[@]}" -czf "$output" "$base"
    fi

    chmod 600 "$output"
    monitor_file_size_once "Архив сайта" "$output" "$estimated_size"
    log_success "Архив сайта создан: $output ($(human_bytes "$(file_size "$output")"))"
    printf '%s' "$output"
}

create_extra_paths_archive() {
    local backup_dir="$1"
    local ts="$2"
    if [ -z "${EXTRA_PATHS:-}" ]; then
        return 0
    fi
    local output="${backup_dir}/extra_paths_${ts}.tar.gz"
    local existing=()
    local item
    local IFS=','
    for item in $EXTRA_PATHS; do
        item="$(printf '%s' "$item" | sed 's/^ *//;s/ *$//')"
        if [ -e "$item" ]; then
            existing+=("$item")
        else
            log_warn "Дополнительный путь пропущен, не найден: $item"
        fi
    done
    if [ "${#existing[@]}" -eq 0 ]; then
        log_warn "EXTRA_PATHS задан, но ни один путь не найден."
        return 0
    fi
    log_info "Архивируются дополнительные пути: ${existing[*]}"
    tar -czf "$output" "${existing[@]}"
    chmod 600 "$output"
    log_success "Архив дополнительных путей создан: $output ($(human_bytes "$(file_size "$output")"))"
    printf '%s' "$output"
}
