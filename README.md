# Backup-S3

Backup-S3 — универсальный CLI/TUI-инструмент для резервного копирования сайтов, директорий и баз данных в S3-совместимое объектное хранилище. Основной сценарий: Linux-сервер с сайтом и MySQL/MariaDB, регулярная выгрузка бэкапов в Yandex Cloud Object Storage или другой S3 endpoint.

## Возможности

- Интерактивное TUI-меню командой `backup-s3`.
- CLI-режимы `--run`, `--background`, `--status`, `--logs`, `--check`, `--dry-run`.
- Дамп MySQL/MariaDB, архитектурная поддержка PostgreSQL.
- Архивация `SITE_DIR` с исключениями и дополнительными путями `EXTRA_PATHS`.
- Создание `SHA256SUMS.txt` и `backup_meta.json`.
- Загрузка в S3 с указанным `S3_STORAGE_CLASS`, например `COLD`.
- Проверка появления файлов в bucket после загрузки.
- `status.json` для онлайн-мониторинга и `state.json` для последнего результата.
- Защита от параллельного запуска через lock-файл.
- Маскирование секретов в выводе.
- systemd service/timer для ежедневного запуска.

## Быстрая Установка

```bash
sudo ./scripts/install.sh
sudo nano /etc/backup-s3/backup-s3.env
sudo backup-s3 --check
sudo backup-s3
```

После запуска без аргументов откроется TUI-меню.

## Основные Команды

```bash
sudo backup-s3 --run
sudo backup-s3 --background
sudo backup-s3 --status
sudo backup-s3 --logs
sudo backup-s3 --check
sudo backup-s3 --dry-run
sudo backup-s3 --list-local
sudo backup-s3 --list-remote
sudo backup-s3 --verify-last
sudo backup-s3 --install-systemd
sudo backup-s3 --install-timer
sudo backup-s3 --enable-timer
```

## Конфигурация

Основной конфиг:

```text
/etc/backup-s3/backup-s3.env
```

Пример лежит в `config/backup-s3.env.example`. Реальные ключи, пароли, пути сайтов и локальные `.env` нельзя добавлять в репозиторий.

Права на конфиг:

```bash
sudo chmod 600 /etc/backup-s3/backup-s3.env
```

## Структура В S3

```text
s3://<S3_BUCKET>/<S3_PREFIX>/<YYYY-MM-DD_HH-MM-SS>/
    <DB_NAME>_<YYYY-MM-DD_HH-MM-SS>.sql.gz
    <SITE_NAME>_files_<YYYY-MM-DD_HH-MM-SS>.tar.gz
    SHA256SUMS.txt
    backup_meta.json
```

Если `S3_PREFIX` пустой, используется `SITE_NAME`, а если он тоже пустой — `BACKUP_PROFILE_NAME`.

## Онлайн-Мониторинг

Во время бэкапа инструмент пишет:

```text
/var/run/backup-s3/status.json
/var/lib/backup-s3/state.json
```

Посмотреть прогресс:

```bash
sudo backup-s3 --status
sudo backup-s3 --logs
sudo backup-s3
```

В TUI выберите пункт "Смотреть онлайн-прогресс текущего бэкапа".

## Пример Для Yandex Cloud Object Storage

```env
S3_PROVIDER="yandex"
S3_ENDPOINT="https://storage.yandexcloud.net"
S3_BUCKET="my-backup-bucket"
S3_REGION="ru-central1"
S3_STORAGE_CLASS="COLD"
S3_ACCESS_KEY_ID="..."
S3_SECRET_ACCESS_KEY="..."
```

Ключи создавайте как static access key сервисного аккаунта с минимальными правами на нужный bucket.

## Безопасность

- Не храните реальные `.env`, ключи, логи и архивы в репозитории.
- Используйте отдельного пользователя БД только для бэкапов.
- Не выводите секреты в команды shell и историю.
- Включите `ENCRYPT_BACKUP="true"`, если в bucket могут лежать чувствительные данные.
- Проверяйте `sudo backup-s3 --show-config`: секреты должны быть замаскированы.

## Частые Ошибки

- `Не найден aws cli`: установите `pip3 install awscli`.
- `Нет доступа к bucket`: проверьте ключи, endpoint, bucket и права сервисного аккаунта.
- `Нет доступа к MySQL`: проверьте пользователя, пароль, host, port и grants.
- `Недостаточно свободного места`: освободите диск или измените `BACKUP_ROOT`.
- `Файл конфигурации имеет небезопасные права`: выполните `sudo chmod 600 /etc/backup-s3/backup-s3.env`.

Подробности: `INSTALL.md`, `CONFIG.md`, `RESTORE.md`, `TROUBLESHOOTING.md`, `SECURITY.md`.
