#!/usr/bin/env bash
set -Eeuo pipefail

dialog_menu() {
    local choice
    while true; do
        load_config 2>/dev/null || true
        choice="$(dialog --clear --title "Backup-S3" --menu "Резервное копирование в S3-хранилище\nПрофиль: ${BACKUP_PROFILE_NAME:-default}\nСайт/проект: ${SITE_NAME:-не задано}\nBucket: ${S3_BUCKET:-не задано}" 30 90 25 \
            1 "Запустить бэкап сейчас" \
            2 "Запустить бэкап в фоне" \
            3 "Смотреть онлайн-прогресс текущего бэкапа" \
            4 "Посмотреть статус текущего бэкапа" \
            5 "Смотреть лог в реальном времени" \
            6 "Посмотреть последние локальные бэкапы" \
            7 "Посмотреть бэкапы в S3-хранилище" \
            8 "Проверить все настройки" \
            9 "Проверить подключение к базе данных" \
            10 "Проверить подключение к S3" \
            11 "Проверить свободное место на диске" \
            12 "Проверить зависимости" \
            13 "Установить/обновить зависимости" \
            14 "Установить systemd service" \
            15 "Установить systemd timer" \
            16 "Включить ежедневный автозапуск" \
            17 "Отключить ежедневный автозапуск" \
            18 "Посмотреть статус systemd timer" \
            19 "Открыть файл конфигурации" \
            20 "Показать конфигурацию с маскировкой секретов" \
            21 "Показать путь к логам" \
            22 "Проверить целостность последнего локального бэкапа" \
            23 "Проверить свежесть последнего успешного бэкапа" \
            24 "Тестовый режим без загрузки в облако" \
            25 "Показать справку" \
            0 "Выход" 3>&1 1>&2 2>&3)" || break
        clear || true
        case "$choice" in
            1) "$0" --run; pause_tui ;;
            2) "$0" --background; pause_tui ;;
            3) live_monitor_status ;;
            4) "$0" --status; pause_tui ;;
            5) show_latest_log ;;
            6) "$0" --list-local; pause_tui ;;
            7) "$0" --list-remote; pause_tui ;;
            8) "$0" --check; pause_tui ;;
            9) load_config && check_database_access; pause_tui ;;
            10) load_config && check_s3_access && check_s3_write_delete; pause_tui ;;
            11) load_config && check_free_space; pause_tui ;;
            12) load_config && check_dependencies; pause_tui ;;
            13) load_config && check_dependencies; pause_tui ;;
            14) "$0" --install-systemd; pause_tui ;;
            15) "$0" --install-timer; pause_tui ;;
            16) "$0" --enable-timer; pause_tui ;;
            17) "$0" --disable-timer; pause_tui ;;
            18) "$0" --timer-status; pause_tui ;;
            19) open_editor_for_config ;;
            20) load_config && show_effective_config_masked; pause_tui ;;
            21) load_config && echo "Логи: $LOG_DIR"; pause_tui ;;
            22) "$0" --verify-last; pause_tui ;;
            23) check_last_backup_freshness; pause_tui ;;
            24) "$0" --dry-run; pause_tui ;;
            25) "$0" --help; pause_tui ;;
            0) break ;;
        esac
    done
    clear || true
}

run_tui() {
    if [ "${TUI_BACKEND:-auto}" = "dialog" ] || { [ "${TUI_BACKEND:-auto}" = "auto" ] && command_exists dialog; }; then
        dialog_menu
    else
        tui_fallback_menu
    fi
}
