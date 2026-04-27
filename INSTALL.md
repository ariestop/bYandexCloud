# Установка Backup-S3

## CentOS 7

```bash
sudo ./scripts/install.sh
```

Скрипт установит зависимости, создаст директории, скопирует файлы в `/usr/local/bin` и `/usr/local/lib/backup-s3`, создаст пример конфига и основной конфиг, если его ещё нет.

## Зависимости

Для CentOS 7:

```bash
sudo yum install -y epel-release
sudo yum install -y tar gzip findutils coreutils pv dialog ncurses jq python3 python3-pip mysql
sudo pip3 install awscli
```

Для Debian/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y tar gzip findutils coreutils pv dialog jq python3 python3-pip default-mysql-client
sudo pip3 install awscli
```

## Директории После Установки

```text
/usr/local/bin/backup-s3
/usr/local/lib/backup-s3/
/etc/backup-s3/backup-s3.env
/etc/backup-s3/backup-s3.env.example
/var/log/backup-s3/
/opt/backup-s3/
/var/lib/backup-s3/
/var/run/backup-s3/
```

## Настройка Конфига

```bash
sudo nano /etc/backup-s3/backup-s3.env
sudo chmod 600 /etc/backup-s3/backup-s3.env
```

Минимально заполните:

```env
SITE_NAME="example.com"
SITE_DIR="/var/www/example.com"
DB_ENABLED="true"
DB_TYPE="mysql"
DB_NAME="example_db"
DB_USER="backup_user"
DB_PASS=""
S3_BUCKET="example-bucket"
S3_PREFIX=""
S3_ACCESS_KEY_ID=""
S3_SECRET_ACCESS_KEY=""
```

## Yandex Cloud Object Storage

1. Создайте bucket.
2. Создайте сервисный аккаунт.
3. Выдайте минимальные права на нужный bucket.
4. Создайте static access key.
5. Запишите ключи в `/etc/backup-s3/backup-s3.env`.

Параметры:

```env
S3_PROVIDER="yandex"
S3_ENDPOINT="https://storage.yandexcloud.net"
S3_REGION="ru-central1"
S3_STORAGE_CLASS="COLD"
```

## Проверка

```bash
sudo backup-s3 --check
sudo backup-s3 --dry-run
```

## Systemd

```bash
sudo backup-s3 --install-systemd
sudo backup-s3 --install-timer
sudo backup-s3 --enable-timer
sudo backup-s3 --timer-status
```

Ручной запуск service:

```bash
sudo systemctl start backup-s3.service
sudo journalctl -u backup-s3.service -f
```

## Запуск TUI

```bash
sudo backup-s3
```

Если `dialog` не установлен, откроется простой текстовый fallback-режим.
