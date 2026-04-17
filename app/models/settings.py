from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass
class Settings:
    game_settings_dir: str = ""
    game_settings_file: str = ""
    game_exe_path: str = ""
    backup_enabled: bool = True
    warn_if_game_running: bool = True
    launch_game_after_activation: bool = False

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Settings":
        return cls(
            game_settings_dir=str(data.get("game_settings_dir", "")),
            game_settings_file=str(data.get("game_settings_file", "")),
            game_exe_path=str(data.get("game_exe_path", "")),
            backup_enabled=bool(data.get("backup_enabled", True)),
            warn_if_game_running=bool(data.get("warn_if_game_running", True)),
            launch_game_after_activation=bool(data.get("launch_game_after_activation", False)),
        )
