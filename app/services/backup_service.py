from __future__ import annotations

from datetime import datetime
from pathlib import Path
import shutil


class BackupService:
    def __init__(self, backup_dir: Path) -> None:
        self.backup_dir = backup_dir
        self.backup_dir.mkdir(parents=True, exist_ok=True)

    def create_backup(self, source_file: Path) -> Path:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        target = self.backup_dir / f"gameSettings_{timestamp}.xml"
        shutil.copy2(source_file, target)
        return target
