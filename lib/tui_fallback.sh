#!/usr/bin/env bash
set -Eeuo pipefail

tui_header() {
    clear || true
    load_config 2>/dev/null || true
    local current_status="нет активного бэкапа"
    if [ -f "$(status_file 2>/dev/null || echo /dev/null)" ]; then
        current_status="$(sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$(status_file)" | head -n 1 || true)"
    fi
    echo "============================================================"
    echo "                    Backup-S3"
    echo "        Резервное копирование в S3-хранилище"
    echo "============================================================"
    echo "Профиль: ${BACKUP_PROFILE_NAME:-default}"
    echo "Сайт/проект: ${SITE_NAME:-не задано}"
    echo "Хранилище: ${S3_PROVIDER:-не задано}"
    echo "Bucket: ${S3_BUCKET:-не задано}"
    echo "Статус: ${current_status:-нет активного бэкапа}"
    echo
}

pause_tui() {
    echo
    read -r -p "Нажмите Enter для продолжения..."
}

open_editor_for_config() {
    load_config || true
    local editor="${EDITOR:-}"
    if [ -z "$editor" ]; then
        if command_exists nano; then
            editor="nano"
        elif command_exists vi; then
            editor="vi"
        else
            echo "Не найден редактор nano или vi. Откройте файл вручную: $CONFIG_FILE"
            return 0
        fi
    fi
    "$editor" "$CONFIG_FILE"
}

show_latest_log() {
    load_config || true
    if [ -n "${LOG_FILE:-}" ] && [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
        return 0
    fi
    local latest
    latest="$(find "${LOG_DIR:-/var/log/backup-s3}" -type f -name '*.log' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {$1=""; sub(/^ /,""); print}')"
    if [ -z "$latest" ]; then
        echo "Логи не найдены."
        return 0
    fi
    tail -f "$latest"
}

tui_fallback_menu() {
    while true; do
        tui_header
        cat <<'MENU'
[1] Запустить бэкап сейчас
[2] Запустить бэкап в фоне
[3] Смотреть онлайн-прогресс текущего бэкапа
[4] Посмотреть статус текущего бэкапа
[5] Смотреть лог в реальном времени
[6] Посмотреть последние локальные бэкапы
[7] Посмотреть бэкапы в S3-хранилище
[8] Проверить все настройки
[9] Проверить подключение к базе данных
[10] Проверить подключение к S3
[11] Проверить свободное место на диске
[12] Проверить зависимости
[13] Установить/обновить зависимости
[14] Установить systemd service
[15] Установить systemd timer
[16] Включить ежедневный автозапуск
[17] Отключить ежедневный автозапуск
[18] Посмотреть статус systemd timer
[19] Открыть файл конфигурации
[20] Показать конфигурацию с маскировкой секретов
[21] Показать путь к логам
[22] Проверить целостность последнего локального бэкапа
[23] Проверить свежесть последнего успешного бэкапа
[24] Тестовый режим без загрузки в облако
[25] Показать справку
[0] Выход
MENU
        echo
        read -r -p "Выбор: " choice
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
            0) exit 0 ;;
            *) echo "Неизвестный пункт меню."; pause_tui ;;
        esac
    done
}
