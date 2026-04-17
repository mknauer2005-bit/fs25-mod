from __future__ import annotations

from pathlib import Path

APP_DIR_NAME = "FS25ModProfilesManager"


def get_app_data_dir() -> Path:
    base = Path.home() / "AppData" / "Local"
    return base / APP_DIR_NAME


def ensure_data_structure() -> dict[str, Path]:
    root = get_app_data_dir()
    backups = root / "backups"
    root.mkdir(parents=True, exist_ok=True)
    backups.mkdir(parents=True, exist_ok=True)

    return {
        "root": root,
        "settings": root / "settings.json",
        "profiles": root / "profiles.json",
        "backups": backups,
        "log": root / "app.log",
    }


def normalize_windows_path(path: str) -> str:
    if not path:
        return ""
    p = Path(path).expanduser()
    try:
        p = p.resolve(strict=False)
    except OSError:
        p = p.absolute()
    return str(p)
