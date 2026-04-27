# Восстановление Из Backup-S3

Полное автоматическое восстановление в первой версии не выполняется. Ниже ручной и проверяемый порядок восстановления.

## Посмотреть Бэкапы В S3

```bash
sudo backup-s3 --list-remote
```

Или напрямую:

```bash
aws --endpoint-url https://storage.yandexcloud.net s3 ls s3://BUCKET/PREFIX/ --recursive
```

## Скачать Нужный Бэкап

```bash
mkdir -p /root/restore/backup-s3
aws --endpoint-url https://storage.yandexcloud.net s3 cp s3://BUCKET/PREFIX/2026-04-27_03-30-00/ /root/restore/backup-s3/ --recursive
cd /root/restore/backup-s3
```

## Проверить SHA256SUMS

```bash
sha256sum -c SHA256SUMS.txt
```

Если checksum не совпадает, не используйте повреждённый архив. Повторите скачивание и проверьте, что в bucket лежит полный набор файлов.

## Распаковать Архив Сайта

```bash
mkdir -p /root/restore/site
tar -xzf example.com_files_2026-04-27_03-30-00.tar.gz -C /root/restore/site
```

Затем перенесите файлы в нужную директорию сайта и проверьте владельца:

```bash
chown -R nginx:nginx /var/www/example.com
find /var/www/example.com -type d -exec chmod 755 {} \;
find /var/www/example.com -type f -exec chmod 644 {} \;
```

Пользователь и группа зависят от вашего веб-сервера.

## Восстановить MySQL/MariaDB

Создайте базу:

```bash
mysql -u root -p -e "CREATE DATABASE example_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

Восстановите дамп:

```bash
gunzip -c example_db_2026-04-27_03-30-00.sql.gz | mysql -u root -p example_db
```

## Восстановить PostgreSQL

```bash
createdb example_db
gunzip -c example_db_2026-04-27_03-30-00.sql.gz | psql example_db
```

## Если Архив Зашифрован

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -pass file:/etc/backup-s3/encryption.key -in file.tar.gz.enc -out file.tar.gz
```

## Проверка После Восстановления

```bash
nginx -t
systemctl reload nginx
systemctl restart php-fpm
```

Проверьте:

- права файлов;
- конфиги сайта;
- подключение к базе;
- логи веб-сервера;
- работу сайта из браузера.

## Проверить Последний Локальный Бэкап

```bash
sudo backup-s3 --verify-last
```
