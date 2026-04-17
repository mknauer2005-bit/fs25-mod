from __future__ import annotations

import os
from pathlib import Path
import webbrowser


class GameLauncher:
    @classmethod
    def launch(cls, game_exe_path: str, launch_type: str = "exe", steam_app_id: str | None = None) -> None:
        if launch_type == "steam" and steam_app_id:
            steam_url = f"steam://run/{steam_app_id.strip()}"
            steam_opened = False
            try:
                steam_opened = bool(webbrowser.open(steam_url))
            except Exception:
                steam_opened = False

            if steam_opened:
                return

        exe = Path(game_exe_path)
        if not exe.exists() or not exe.is_file():
            raise FileNotFoundError("EXE не найден")
        os.startfile(str(exe))  # type: ignore[attr-defined]
