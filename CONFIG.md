# Конфигурация Backup-S3

Основной файл:

```text
/etc/backup-s3/backup-s3.env
```

Права:

```bash
sudo chmod 600 /etc/backup-s3/backup-s3.env
```

## Основные Переменные

- `APP_NAME` — имя приложения.
- `APP_VERSION` — версия.
- `BACKUP_PROFILE_NAME` — имя профиля, сейчас используется один профиль `default`.
- `SITE_NAME` — имя сайта или проекта.
- `SITE_DIR` — директория сайта или проекта.
- `BACKUP_ROOT` — место локального создания бэкапов.
- `LOG_DIR` — директория логов.
- `STATE_DIR` — долговременное состояние.
- `RUNTIME_DIR` — текущий runtime-статус.

## База Данных

```env
DB_ENABLED="true"
DB_TYPE="mysql"
DB_NAME=""
DB_USER=""
DB_PASS=""
DB_HOST="localhost"
DB_PORT="3306"
```

Отключить дамп БД:

```env
DB_ENABLED="false"
```

PostgreSQL архитектурно поддержан через `DB_TYPE="postgres"`, для него нужны `pg_dump` и `psql`.

## S3

```env
S3_PROVIDER="yandex"
S3_ENDPOINT="https://storage.yandexcloud.net"
S3_BUCKET=""
S3_PREFIX=""
S3_STORAGE_CLASS="COLD"
S3_REGION="ru-central1"
S3_ACCESS_KEY_ID=""
S3_SECRET_ACCESS_KEY=""
```

Если `S3_PREFIX` пустой, используется `SITE_NAME` или `BACKUP_PROFILE_NAME`.

## Исключения И Дополнительные Пути

```env
EXTRA_PATHS="/etc/nginx,/etc/php-fpm.d"
EXCLUDE_PATHS="cache,tmp,logs,log,node_modules,vendor,.git"
```

`EXTRA_PATHS` перечисляются через запятую. Несуществующие пути пропускаются с предупреждением.

## Шифрование

```env
ENCRYPT_BACKUP="true"
ENCRYPTION_METHOD="openssl"
ENCRYPTION_PASSWORD_FILE="/etc/backup-s3/encryption.key"
```

Создать файл ключа:

```bash
sudo install -m 600 /dev/null /etc/backup-s3/encryption.key
sudo nano /etc/backup-s3/encryption.key
```

Если шифрование включено, в S3 загружаются зашифрованные файлы `.enc`.

## Команды До И После Бэкапа

```env
PRE_BACKUP_COMMAND=""
POST_BACKUP_COMMAND=""
```

Если `PRE_BACKUP_COMMAND` завершится ошибкой, бэкап остановится. Ошибка `POST_BACKUP_COMMAND` после успешной загрузки считается предупреждением.

## Dry-Run

```bash
sudo backup-s3 --dry-run
```

Команда показывает используемый конфиг, `SITE_DIR`, БД, исключения, bucket и будущий S3 target без реальной загрузки.
