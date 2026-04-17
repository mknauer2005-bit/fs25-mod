from __future__ import annotations

import subprocess
from pathlib import Path


class ProcessService:
    @staticmethod
    def is_game_running(game_exe_path: str) -> bool:
        if not game_exe_path:
            return False

        exe_name = Path(game_exe_path).name.lower()
        if not exe_name:
            return False

        try:
            result = subprocess.run(
                ["tasklist", "/FO", "CSV", "/NH"],
                capture_output=True,
                text=True,
                check=False,
            )
        except OSError:
            return False

        output = result.stdout.lower()
        return exe_name in output
