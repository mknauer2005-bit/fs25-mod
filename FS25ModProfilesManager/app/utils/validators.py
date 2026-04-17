from __future__ import annotations

from pathlib import Path


def path_exists(path: str) -> bool:
    return bool(path) and Path(path).exists()


def is_existing_dir(path: str) -> bool:
    return bool(path) and Path(path).is_dir()


def is_existing_file(path: str) -> bool:
    return bool(path) and Path(path).is_file()


def not_blank(value: str) -> bool:
    return bool(value and value.strip())
