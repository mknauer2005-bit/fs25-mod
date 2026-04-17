from __future__ import annotations

from pathlib import Path
import sys

from app.ui.main_window import MainWindow
from app.utils.logging_config import setup_logging
from app.utils.paths import ensure_data_structure


ICON_FILENAME = "fs25_mod_manager.ico"


def _resolve_icon_path() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent / ICON_FILENAME
    return Path(__file__).resolve().parents[1] / ICON_FILENAME


def main() -> None:
    paths = ensure_data_structure()
    setup_logging(paths["log"])
    app = MainWindow()

    icon_path = _resolve_icon_path()
    if icon_path.exists():
        try:
            app.iconbitmap(str(icon_path))
        except Exception:
            pass

    app.mainloop()


if __name__ == "__main__":
    main()
