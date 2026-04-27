#!/usr/bin/env bash
set -Eeuo pipefail

status_file() {
    printf '%s/status.json' "${RUNTIME_DIR:-/var/run/backup-s3}"
}

state_file() {
    printf '%s/state.json' "${STATE_DIR:-/var/lib/backup-s3}"
}

ensure_state_dirs() {
    ensure_dir "${RUNTIME_DIR:-/var/run/backup-s3}"
    ensure_dir "${STATE_DIR:-/var/lib/backup-s3}"
}

write_status() {
    local status="${1:-idle}"
    local stage="${2:-}"
    local stage_no="${3:-0}"
    local total_stages="${4:-0}"
    local overall_percent="${5:-0}"
    local operation="${6:-}"
    local local_percent="${7:-}"
    local processed_bytes="${8:-0}"
    local total_bytes="${9:-0}"
    local speed="${10:-}"
    local eta="${11:-}"
    local error_message="${12:-}"

    ensure_state_dirs
    local file
    file="$(status_file)"
    local pid_value="${BACKUP_PID:-$$}"
    local last_success_at=""
    if [ -f "$(state_file)" ]; then
        last_success_at="$(sed -n 's/.*"last_success_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$(state_file)" | head -n 1 || true)"
    fi

    cat > "${file}.tmp" <<EOF
{
  "app": "$(json_escape "${APP_NAME:-Backup-S3}")",
  "version": "$(json_escape "${APP_VERSION:-1.0.0}")",
  "profile": "$(json_escape "${BACKUP_PROFILE_NAME:-default}")",
  "pid": ${pid_value},
  "status": "$(json_escape "$status")",
  "stage": "$(json_escape "$stage")",
  "stage_no": ${stage_no},
  "total_stages": ${total_stages},
  "overall_percent": ${overall_percent},
  "operation": "$(json_escape "$operation")",
  "local_percent": "$(json_escape "$local_percent")",
  "processed_bytes": ${processed_bytes},
  "total_bytes": ${total_bytes},
  "speed": "$(json_escape "$speed")",
  "eta": "$(json_escape "$eta")",
  "started_at": "$(json_escape "${BACKUP_STARTED_AT:-}")",
  "updated_at": "$(iso_now)",
  "current_log_file": "$(json_escape "${LOG_FILE:-}")",
  "current_backup_dir": "$(json_escape "${CURRENT_BACKUP_DIR:-}")",
  "current_s3_target": "$(json_escape "${CURRENT_S3_TARGET:-}")",
  "error_message": "$(json_escape "$error_message")",
  "last_success_at": "$(json_escape "$last_success_at")"
}
EOF
    mv "${file}.tmp" "$file"
}

write_state() {
    local status="$1"
    local message="${2:-}"
    local meta_path="${3:-}"
    ensure_state_dirs
    local success_at=""
    if [ "$status" = "success" ]; then
        success_at="$(iso_now)"
    elif [ -f "$(state_file)" ]; then
        success_at="$(sed -n 's/.*"last_success_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$(state_file)" | head -n 1 || true)"
    fi
    cat > "$(state_file).tmp" <<EOF
{
  "app": "$(json_escape "${APP_NAME:-Backup-S3}")",
  "version": "$(json_escape "${APP_VERSION:-1.0.0}")",
  "profile": "$(json_escape "${BACKUP_PROFILE_NAME:-default}")",
  "last_status": "$(json_escape "$status")",
  "last_message": "$(json_escape "$message")",
  "last_run_at": "$(iso_now)",
  "last_success_at": "$(json_escape "$success_at")",
  "last_log_file": "$(json_escape "${LOG_FILE:-}")",
  "last_backup_dir": "$(json_escape "${CURRENT_BACKUP_DIR:-}")",
  "last_s3_target": "$(json_escape "${CURRENT_S3_TARGET:-}")",
  "last_meta_file": "$(json_escape "$meta_path")"
}
EOF
    mv "$(state_file).tmp" "$(state_file)"
}

show_status_pretty() {
    local file
    file="$(status_file)"
    if [ ! -f "$file" ]; then
        echo "Статус ещё не создан. Бэкап не запускался или runtime-директория очищена."
        return 0
    fi
    if command_exists jq; then
        jq -r '
          "Статус: \(.status)\nPID: \(.pid)\nЭтап: \(.stage_no)/\(.total_stages) - \(.stage)\nОбщий прогресс: \(.overall_percent)%\nОперация: \(.operation)\nЛокальный прогресс: \(.local_percent)\nОбработано: \(.processed_bytes) / \(.total_bytes) байт\nСкорость: \(.speed)\nETA: \(.eta)\nЛог: \(.current_log_file)\nS3: \(.current_s3_target)\nОшибка: \(.error_message)"' "$file"
    else
        sed -n '1,200p' "$file"
    fi
}

show_status_json() {
    local file
    file="$(status_file)"
    if [ -f "$file" ]; then
        sed -n '1,200p' "$file"
    else
        echo "{}"
    fi
}

show_last_result() {
    local file
    file="$(state_file)"
    if [ -f "$file" ]; then
        sed -n '1,200p' "$file"
    else
        echo "Последний результат ещё не записан."
    fi
}
