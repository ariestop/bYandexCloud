#!/usr/bin/env bash
set -Eeuo pipefail

cleanup_old_local_backups() {
    if [ -z "${BACKUP_ROOT:-}" ] || [ "$BACKUP_ROOT" = "/" ]; then
        log_warn "Очистка пропущена: BACKUP_ROOT небезопасен."
        return 0
    fi
    if [ ! -d "$BACKUP_ROOT" ]; then
        log_info "Очистка пропущена: BACKUP_ROOT не существует."
        return 0
    fi
    log_info "Удаляются локальные бэкапы старше ${LOCAL_RETENTION_DAYS} дней в $BACKUP_ROOT"
    safe_rm_dir_children_older_than "$BACKUP_ROOT" "$LOCAL_RETENTION_DAYS"
}

cleanup_lock() {
    local lock_file="${RUNTIME_DIR:-/var/run/backup-s3}/backup.lock"
    rm -f "$lock_file"
}
