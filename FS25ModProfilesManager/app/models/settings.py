from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass
class Settings:
    selected_game_id: str = ""
    backup_enabled: bool = True
    warn_if_game_running: bool = True
    launch_game_after_activation: bool = False

    # legacy поля для миграции
    game_settings_dir: str = ""
    game_settings_file: str = ""
    game_exe_path: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "selected_game_id": self.selected_game_id,
            "backup_enabled": self.backup_enabled,
            "warn_if_game_running": self.warn_if_game_running,
            "launch_game_after_activation": self.launch_game_after_activation,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Settings":
        return cls(
            selected_game_id=str(data.get("selected_game_id", "")),
            backup_enabled=bool(data.get("backup_enabled", True)),
            warn_if_game_running=bool(data.get("warn_if_game_running", True)),
            launch_game_after_activation=bool(data.get("launch_game_after_activation", False)),
            game_settings_dir=str(data.get("game_settings_dir", "")),
            game_settings_file=str(data.get("game_settings_file", "")),
            game_exe_path=str(data.get("game_exe_path", "")),
        )
