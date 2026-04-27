#!/usr/bin/env python3
"""Дополнительный Rich-монитор статуса Backup-S3."""

import json
import os
import time
from pathlib import Path

try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.progress import BarColumn, Progress, TextColumn
except ImportError:
    print("Python TUI требует пакет rich. Установите: pip3 install -r tui/requirements.txt")
    raise SystemExit(3)


def status_path() -> Path:
    return Path(os.environ.get("BACKUP_S3_STATUS_FILE", "/var/run/backup-s3/status.json"))


def read_status() -> dict:
    path = status_path()
    if not path.exists():
        return {"status": "idle", "stage": "status.json не найден", "overall_percent": 0}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        return {"status": "error", "stage": f"Не удалось прочитать status.json: {exc}", "overall_percent": 0}


def main() -> None:
    console = Console()
    while True:
        data = read_status()
        console.clear()
        percent = int(data.get("overall_percent") or 0)
        with Progress(
            TextColumn("[bold blue]Общий прогресс"),
            BarColumn(),
            TextColumn("{task.percentage:>3.0f}%"),
            console=console,
        ) as progress:
            task = progress.add_task("backup", total=100, completed=percent)
            progress.update(task, completed=percent)
        body = "\n".join(
            [
                f"Статус: {data.get('status', '')}",
                f"PID: {data.get('pid', '')}",
                f"Этап: {data.get('stage_no', '')}/{data.get('total_stages', '')} — {data.get('stage', '')}",
                f"Операция: {data.get('operation', '')}",
                f"Локальный прогресс: {data.get('local_percent', '')}",
                f"Обработано: {data.get('processed_bytes', 0)} / {data.get('total_bytes', 0)} байт",
                f"Скорость: {data.get('speed', '')}",
                f"ETA: {data.get('eta', '')}",
                f"Лог: {data.get('current_log_file', '')}",
                f"S3: {data.get('current_s3_target', '')}",
                f"Ошибка: {data.get('error_message', '')}",
            ]
        )
        console.print(Panel(body, title="Backup-S3 онлайн-мониторинг"))
        console.print("Обновление каждые 2 секунды. Ctrl+C для выхода.")
        time.sleep(2)


if __name__ == "__main__":
    main()
