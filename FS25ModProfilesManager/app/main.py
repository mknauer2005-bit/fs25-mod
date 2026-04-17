from __future__ import annotations

from pathlib import Path
import sys

from app.ui.main_window import MainWindow
from app.utils.logging_config import setup_logging
from app.utils.paths import ensure_data_structure


ICON_FILENAME = "fs25_mod_manager.ico"
APP_USER_MODEL_ID = "Svapa.FS25ModProfilesManager.1"


def _resolve_icon_path() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent / ICON_FILENAME
    return Path(__file__).resolve().parents[1] / ICON_FILENAME


def _apply_windows_app_id() -> None:
    if not sys.platform.startswith("win"):
        return
    try:
        import ctypes

        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_USER_MODEL_ID)
    except Exception:
        pass


def _apply_window_icon(app: MainWindow, icon_path: Path) -> None:
    if not icon_path.exists():
        return

    try:
        app.wm_iconbitmap(str(icon_path))
        app.iconbitmap(str(icon_path))
    except Exception:
        pass


def main() -> None:
    paths = ensure_data_structure()
    setup_logging(paths["log"])

    _apply_windows_app_id()

    app = MainWindow()
    _apply_window_icon(app, _resolve_icon_path())

    app.mainloop()


if __name__ == "__main__":
    main()
