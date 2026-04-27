#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Ошибка: установку нужно запускать от root: sudo ./scripts/install.sh" >&2
    exit 1
fi

detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${PRETTY_NAME:-Linux}"
    else
        uname -s
    fi
}

install_dependencies() {
    local os_name
    os_name="$(detect_os)"
    echo "ОС: $os_name"
    if [ -f /etc/centos-release ]; then
        if ! grep -q ' 7\.' /etc/centos-release; then
            echo "Предупреждение: основной целевой дистрибутив — CentOS 7, продолжаю установку."
        fi
    fi

    if command -v yum >/dev/null 2>&1; then
        yum install -y epel-release || true
        yum install -y tar gzip findutils coreutils pv dialog ncurses jq python3 python3-pip mysql || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y tar gzip findutils coreutils pv dialog ncurses jq python3 python3-pip mysql || true
    elif command -v apt-get >/dev/null 2>&1; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y tar gzip findutils coreutils pv dialog jq python3 python3-pip default-mysql-client
    else
        echo "Предупреждение: пакетный менеджер не распознан. Установите зависимости вручную."
    fi

    if ! command -v aws >/dev/null 2>&1; then
        if command -v pip3 >/dev/null 2>&1; then
            pip3 install awscli
        else
            echo "Предупреждение: pip3 не найден, awscli не установлен."
        fi
    fi
}

install_files() {
    install -d -m 755 /usr/local/lib/backup-s3
    install -d -m 755 /usr/local/lib/backup-s3/systemd
    install -d -m 755 /etc/backup-s3
    install -d -m 700 /etc/backup-s3/profiles
    install -d -m 700 /var/log/backup-s3
    install -d -m 700 /opt/backup-s3
    install -d -m 700 /var/lib/backup-s3
    install -d -m 700 /var/run/backup-s3

    cp "$PROJECT_ROOT"/lib/*.sh /usr/local/lib/backup-s3/
    cp "$PROJECT_ROOT"/systemd/backup-s3.service /usr/local/lib/backup-s3/systemd/
    cp "$PROJECT_ROOT"/systemd/backup-s3.timer /usr/local/lib/backup-s3/systemd/
    install -m 755 "$PROJECT_ROOT/bin/backup-s3" /usr/local/bin/backup-s3
    install -m 600 "$PROJECT_ROOT/config/backup-s3.env.example" /etc/backup-s3/backup-s3.env.example

    if [ ! -f /etc/backup-s3/backup-s3.env ]; then
        cp /etc/backup-s3/backup-s3.env.example /etc/backup-s3/backup-s3.env
        chmod 600 /etc/backup-s3/backup-s3.env
        echo "Создан конфиг: /etc/backup-s3/backup-s3.env"
    else
        chmod 600 /etc/backup-s3/backup-s3.env
        echo "Существующий конфиг сохранён: /etc/backup-s3/backup-s3.env"
    fi
}

main() {
    install_dependencies
    install_files
    echo
    echo "Backup-S3 установлен."
    echo "Дальнейшие шаги:"
    echo "1. Отредактируйте конфиг: sudo nano /etc/backup-s3/backup-s3.env"
    echo "2. Проверьте настройки: sudo backup-s3 --check"
    echo "3. Запустите TUI: sudo backup-s3"
    echo
    echo "Пробная проверка:"
    backup-s3 --check || true
}

main "$@"
