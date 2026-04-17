from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any

from app.utils.paths import normalize_windows_path


@dataclass
class GameProfile:
    id: str
    name: str
    game_settings_dir: str = ""
    game_settings_file: str = ""
    game_exe_path: str = ""
    launch_type: str = "steam"
    steam_app_id: str | None = None

    def normalize_paths(self) -> None:
        self.game_settings_dir = normalize_windows_path(self.game_settings_dir)
        self.game_exe_path = normalize_windows_path(self.game_exe_path)
        if self.game_settings_dir:
            self.game_settings_file = str(Path(self.game_settings_dir) / "gameSettings.xml")
        else:
            self.game_settings_file = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "GameProfile":
        profile = cls(
            id=str(data.get("id", "")),
            name=str(data.get("name", "")),
            game_settings_dir=str(data.get("game_settings_dir", "")),
            game_settings_file=str(data.get("game_settings_file", "")),
            game_exe_path=str(data.get("game_exe_path", "")),
            launch_type=str(data.get("launch_type", "steam")),
            steam_app_id=str(data.get("steam_app_id", "")).strip() or None,
        )
        profile.normalize_paths()
        return profile
