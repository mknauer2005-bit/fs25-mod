from __future__ import annotations

import os
from pathlib import Path
import webbrowser


class GameLauncher:
    DEFAULT_STEAM_APP_ID = "2300320"

    @classmethod
    def launch(cls, game_exe_path: str, launch_type: str = "exe", steam_app_id: str | None = None) -> None:
        if launch_type == "steam":
            app_id = (steam_app_id or cls.DEFAULT_STEAM_APP_ID).strip()
            steam_url = f"steam://run/{app_id}"
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
