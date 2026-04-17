from __future__ import annotations

from pathlib import Path


class ModFolderValidator:
    @staticmethod
    def validate_folder(path: str) -> tuple[bool, str]:
        folder = Path(path)
        if not folder.exists() or not folder.is_dir():
            return False, "Папка не найдена"

        try:
            entries = list(folder.iterdir())
        except OSError:
            return False, "Папка недоступна"

        if not entries:
            return True, "Папка пуста"

        has_dir = any(item.is_dir() for item in entries)
        if has_dir:
            return True, "Есть моды в папках (не ZIP)"

        has_zip = any(item.is_file() and item.suffix.lower() == ".zip" for item in entries)
        if has_zip:
            return True, "Все моды в ZIP"

        return True, "Папка проверена"
