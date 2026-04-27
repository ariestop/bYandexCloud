#!/usr/bin/env bash
set -Eeuo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "Ошибка: удаление нужно запускать от root: sudo ./scripts/uninstall.sh" >&2
    exit 1
fi

systemctl disable --now backup-s3.timer >/dev/null 2>&1 || true
systemctl stop backup-s3.service >/dev/null 2>&1 || true

rm -f /etc/systemd/system/backup-s3.service
rm -f /etc/systemd/system/backup-s3.timer
systemctl daemon-reload >/dev/null 2>&1 || true

rm -f /usr/local/bin/backup-s3
rm -rf /usr/local/lib/backup-s3

echo "Backup-S3 удалён из /usr/local/bin и /usr/local/lib."
echo "Конфиг и данные сохранены:"
echo "  /etc/backup-s3"
echo "  /var/log/backup-s3"
echo "  /opt/backup-s3"
echo "  /var/lib/backup-s3"
