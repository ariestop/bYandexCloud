# Инструкции Для AI-Агентов

- Cursor project rules находятся в `.cursor/rules/*.mdc`.
- `AGENTS.md` является основным файлом инструкций; Cursor rules должны ссылаться на него и оставаться с ним синхронизированными.
- Вся пользовательская документация, help-сообщения, TUI-тексты и человекочитаемые логи должны быть на русском языке.
- Не добавлять реальные секреты, реальные `.env`, ключи, локальные логи, дампы, архивы и приватные AI/Cursor файлы.
- Технические имена функций, переменных, файлов и CLI-аргументов могут быть на английском языке.
- Не хардкодить путь конкретного сайта, имя БД, bucket, access key или secret key.
- Все настройки должны идти через `/etc/backup-s3/backup-s3.env` или env-example без секретов.
- Для Bash-кода использовать `set -Eeuo pipefail`, кавычки вокруг переменных, безопасную очистку и понятные exit codes.
- Не использовать `eval`.
- После изменений запускать:

```bash
bash -n bin/backup-s3 lib/*.sh scripts/*.sh tests/*.sh
bash tests/test-config.sh
bash tests/test-functions.sh
bash tests/test-secrets.sh
bash tests/test-s3-target.sh
```

- Если доступен ShellCheck:

```bash
bash scripts/dev-shellcheck.sh
```
