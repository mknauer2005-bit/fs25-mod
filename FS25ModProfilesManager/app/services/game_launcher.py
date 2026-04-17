from __future__ import annotations

import os
from pathlib import Path
import webbrowser


class GameLauncher:
    STEAM_RUN_URL = "steam://run/2300320"

    @classmethod
    def launch(cls, game_exe_path: str) -> None:
        steam_opened = False
        try:
            steam_opened = bool(webbrowser.open(cls.STEAM_RUN_URL))
        except Exception:
            steam_opened = False

        if steam_opened:
            return

        exe = Path(game_exe_path)
        if not exe.exists() or not exe.is_file():
            raise FileNotFoundError("Не удалось запустить через Steam, EXE не найден")
        os.startfile(str(exe))  # type: ignore[attr-defined]
