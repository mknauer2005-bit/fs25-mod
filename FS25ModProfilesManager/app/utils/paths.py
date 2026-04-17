from __future__ import annotations

from pathlib import Path
import sys


APP_DIR_NAME = "FS25ModProfilesManager"


def get_base_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parents[2]


def get_app_data_dir() -> Path:
    return get_base_dir() / "data"


def ensure_data_structure() -> dict[str, Path]:
    base_dir = get_base_dir()
    data_dir = get_app_data_dir()
    backups = base_dir / "backups"

    data_dir.mkdir(parents=True, exist_ok=True)
    backups.mkdir(parents=True, exist_ok=True)

    return {
        "base": base_dir,
        "root": data_dir,
        "settings": data_dir / "settings.json",
        "profiles": data_dir / "profiles.json",
        "games": data_dir / "games.json",
        "backups": backups,
        "log": base_dir / "app.log",
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
