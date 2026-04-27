# Безопасность Backup-S3

## Секреты

Не добавляйте в репозиторий:

- реальные `.env`;
- S3 access key и secret key;
- пароли БД;
- приватные ключи;
- логи;
- архивы и дампы.

Основной конфиг должен иметь права:

```bash
sudo chmod 600 /etc/backup-s3/backup-s3.env
sudo chown root:root /etc/backup-s3/backup-s3.env
```

## Пользователь БД Для Бэкапов

Создайте отдельного пользователя с минимальными правами:

```sql
CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'STRONG_PASSWORD';
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES, EVENT ON database_name.* TO 'backup_user'@'localhost';
FLUSH PRIVILEGES;
```

Не вставляйте реальные пароли в публичные инструкции, issue и логи.

## Маскирование

Команда:

```bash
sudo backup-s3 --show-config
```

должна показывать секреты в виде:

```text
DB_PASS="SEC********"
S3_ACCESS_KEY_ID="YCA********"
S3_SECRET_ACCESS_KEY="YCS********"
```

## Шифрование

Включить:

```env
ENCRYPT_BACKUP="true"
ENCRYPTION_METHOD="openssl"
ENCRYPTION_PASSWORD_FILE="/etc/backup-s3/encryption.key"
```

Файл ключа:

```bash
sudo install -m 600 /dev/null /etc/backup-s3/encryption.key
sudo nano /etc/backup-s3/encryption.key
```

Храните ключ восстановления отдельно от bucket.

## Ротация S3-Ключей

1. Создайте новый static access key.
2. Обновите `/etc/backup-s3/backup-s3.env`.
3. Выполните `sudo backup-s3 --check`.
4. После успешной проверки отключите старый ключ.

## Защита От Ошибок Удаления

Backup-S3 удаляет старые локальные бэкапы только внутри `BACKUP_ROOT` и отказывается работать с пустым путём или `/`.

## Cursor И AI-Файлы

Локальные файлы `.cursor/`, приватные правила, локальные agent-файлы и приватные prompts исключены в `.gitignore`. `AGENTS.md` можно хранить в репозитории, если он не содержит секретов.
