# Диагностика Backup-S3

## Где Смотреть Логи

```bash
sudo backup-s3 --logs
ls -lah /var/log/backup-s3/
```

Runtime-статус:

```bash
sudo backup-s3 --status
sudo backup-s3 --status-json
```

Последний результат:

```bash
sudo backup-s3 --last-result
```

## Ошибки MySQL/MariaDB

Сообщение: `Нет доступа к MySQL/MariaDB`.

Проверьте:

```bash
mysql -h DB_HOST -P DB_PORT -u DB_USER -p DB_NAME
```

Права пользователя:

```sql
SHOW GRANTS FOR 'backup_user'@'localhost';
```

## Ошибки PostgreSQL

Проверьте клиент:

```bash
pg_dump --version
psql --version
```

Проверьте доступ:

```bash
psql -h DB_HOST -p DB_PORT -U DB_USER -d DB_NAME -c "SELECT 1;"
```

## Ошибки S3

Проверьте:

```bash
aws --endpoint-url https://storage.yandexcloud.net s3 ls s3://BUCKET/
```

Если нет доступа, проверьте `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_BUCKET`, `S3_ENDPOINT`, регион и права сервисного аккаунта.

## Ошибки Прав

Конфиг:

```bash
sudo chmod 600 /etc/backup-s3/backup-s3.env
sudo chown root:root /etc/backup-s3/backup-s3.env
```

Директории:

```bash
sudo mkdir -p /var/log/backup-s3 /opt/backup-s3 /var/lib/backup-s3 /var/run/backup-s3
sudo chmod 700 /var/log/backup-s3 /opt/backup-s3 /var/lib/backup-s3 /var/run/backup-s3
```

## Недостаточно Места

```bash
df -h
du -sh /opt/backup-s3
```

Увеличьте `BACKUP_ROOT` или очистите старые локальные бэкапы.

## awscli Не Найден

```bash
sudo pip3 install awscli
```

## pv/dialog Не Найдены

`pv` нужен для прогресса тяжёлых операций, `dialog` — для красивого TUI. Без них инструмент работает в fallback-режиме.

```bash
sudo yum install -y epel-release pv dialog
```

## Systemd

```bash
sudo systemctl status backup-s3.service
sudo systemctl status backup-s3.timer
sudo journalctl -u backup-s3.service -n 100 --no-pager
```

## Зависший Lock-Файл

Если бэкап точно не выполняется:

```bash
sudo rm -f /var/run/backup-s3/backup.lock
```

Перед удалением проверьте PID из сообщения об ошибке:

```bash
ps -fp PID
```
