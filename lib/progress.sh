#!/usr/bin/env bash
set -Eeuo pipefail

TOTAL_STAGES=22
CURRENT_STAGE_NO=0

progress_bar() {
    local percent="${1:-0}"
    local width="${2:-30}"
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    printf '['
    printf '%*s' "$filled" '' | tr ' ' '#'
    printf '%*s' "$empty" '' | tr ' ' '-'
    printf '] %s%%' "$percent"
}

set_stage() {
    local stage="$1"
    CURRENT_STAGE_NO=$((CURRENT_STAGE_NO + 1))
    local percent=$((CURRENT_STAGE_NO * 100 / TOTAL_STAGES))
    log_step "Шаг ${CURRENT_STAGE_NO}/${TOTAL_STAGES}: $stage"
    write_status "running" "$stage" "$CURRENT_STAGE_NO" "$TOTAL_STAGES" "$percent" "$stage" "" 0 0 "" "" ""
}

set_operation_progress() {
    local operation="$1"
    local processed="${2:-0}"
    local total="${3:-0}"
    local speed="${4:-}"
    local eta="${5:-}"
    local local_percent=""
    if [ "$total" -gt 0 ]; then
        local_percent="$((processed * 100 / total))%"
    fi
    local overall=$((CURRENT_STAGE_NO * 100 / TOTAL_STAGES))
    write_status "running" "${operation}" "$CURRENT_STAGE_NO" "$TOTAL_STAGES" "$overall" "$operation" "$local_percent" "$processed" "$total" "$speed" "$eta" ""
}

run_with_pv_to_file() {
    local label="$1"
    local total_bytes="$2"
    local output_file="$3"
    shift 3
    if command_exists pv && [ "${PROGRESS_MODE:-auto}" != "off" ] && [ "$total_bytes" -gt 0 ]; then
        "$@" | pv -f -s "$total_bytes" -N "$label" > "$output_file"
    else
        "$@" > "$output_file"
    fi
}

monitor_file_size_once() {
    local label="$1"
    local file="$2"
    local total="${3:-0}"
    local processed=0
    if [ -f "$file" ]; then
        processed="$(file_size "$file" 2>/dev/null || echo 0)"
    fi
    set_operation_progress "$label" "$processed" "$total" "" ""
}

live_monitor_status() {
    while true; do
        clear || true
        echo "============================================================"
        echo "                    Backup-S3"
        echo "          Онлайн-прогресс текущего бэкапа"
        echo "============================================================"
        show_status_pretty
        echo
        echo "Обновление каждые 2 секунды. Нажмите Ctrl+C для выхода."
        sleep 2
    done
}
