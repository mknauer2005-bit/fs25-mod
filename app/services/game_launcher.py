from __future__ import annotations

import os
from pathlib import Path


class GameLauncher:
    @staticmethod
    def launch(game_exe_path: str) -> None:
        exe = Path(game_exe_path)
        if not exe.exists() or not exe.is_file():
            raise FileNotFoundError("EXE не найден")
        os.startfile(str(exe))  # type: ignore[attr-defined]
