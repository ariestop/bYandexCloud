#!/usr/bin/env bash
set -Eeuo pipefail

install_systemd_service() {
    require_root
    local src="${PROJECT_ROOT}/systemd/backup-s3.service"
    [ -f "$src" ] || src="${LIB_DIR:-/usr/local/lib/backup-s3}/systemd/backup-s3.service"
    cp "$src" /etc/systemd/system/backup-s3.service
    systemctl daemon-reload
    echo "systemd service установлен: /etc/systemd/system/backup-s3.service"
}

install_systemd_timer() {
    require_root
    load_config || set_config_defaults
    cat > /etc/systemd/system/backup-s3.timer <<EOF
[Unit]
Description=Ежедневный запуск Backup-S3

[Timer]
OnCalendar=*-*-* ${SYSTEMD_TIMER_TIME:-03:30:00}
Persistent=true
Unit=backup-s3.service

[Install]
WantedBy=timers.target
EOF
    systemctl daemon-reload
    echo "systemd timer установлен: /etc/systemd/system/backup-s3.timer"
    echo "Время запуска: ${SYSTEMD_TIMER_TIME:-03:30:00}"
}

enable_systemd_timer() {
    require_root
    systemctl enable --now backup-s3.timer
    echo "Ежедневный автозапуск включён."
}

disable_systemd_timer() {
    require_root
    systemctl disable --now backup-s3.timer
    echo "Ежедневный автозапуск отключён."
}

show_timer_status() {
    systemctl status backup-s3.timer --no-pager || true
    echo
    systemctl list-timers backup-s3.timer --no-pager || true
}

start_background_service_or_nohup() {
    load_config
    if command_exists systemctl && systemctl list-unit-files backup-s3.service >/dev/null 2>&1; then
        systemctl start backup-s3.service
        echo "Бэкап запущен через systemd service."
        echo "Логи systemd: journalctl -u backup-s3.service -f"
    else
        ensure_dir "$LOG_DIR"
        nohup "$0" --run > "${LOG_DIR}/background.log" 2>&1 &
        local pid=$!
        echo "Бэкап запущен в фоне."
        echo "PID: $pid"
        echo "Лог запуска: ${LOG_DIR}/background.log"
    fi
    echo
    echo "Смотреть онлайн-прогресс: sudo backup-s3 --status"
    echo "Открыть TUI: sudo backup-s3"
    echo "Смотреть лог: sudo backup-s3 --logs"
}
