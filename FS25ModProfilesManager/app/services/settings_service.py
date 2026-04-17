from __future__ import annotations

import json
import logging
from pathlib import Path

from app.models.settings import Settings
from app.utils.paths import normalize_windows_path

logger = logging.getLogger(__name__)


class SettingsService:
    def __init__(self, settings_file: Path) -> None:
        self.settings_file = settings_file

    def load(self) -> Settings:
        if not self.settings_file.exists():
            settings = Settings()
            self.save(settings)
            return settings

        try:
            data = json.loads(self.settings_file.read_text(encoding="utf-8"))
            settings = Settings.from_dict(data)
        except (json.JSONDecodeError, OSError):
            logger.exception("Не удалось прочитать settings.json")
            settings = Settings()
            self.save(settings)

        settings.game_settings_dir = normalize_windows_path(settings.game_settings_dir)
        settings.game_settings_file = normalize_windows_path(settings.game_settings_file)
        settings.game_exe_path = normalize_windows_path(settings.game_exe_path)
        return settings

    def save(self, settings: Settings) -> None:
        self.settings_file.write_text(
            json.dumps(settings.to_dict(), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
