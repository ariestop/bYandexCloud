# ShellCheck

Проверка Bash-кода:

```bash
shellcheck scripts/*.sh lib/*.sh bin/backup-s3 tests/*.sh
```

Если ShellCheck не установлен:

```bash
sudo yum install -y epel-release shellcheck
```

Для Debian/Ubuntu:

```bash
sudo apt-get install -y shellcheck
```

В проекте есть обёртка:

```bash
bash scripts/dev-shellcheck.sh
```
