from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Iterable
from uuid import uuid4

from app.models.profile import Profile
from app.utils.paths import normalize_windows_path

logger = logging.getLogger(__name__)
LEGACY_KEY = "__legacy__"


class ProfileService:
    def __init__(self, profiles_file: Path) -> None:
        self.profiles_file = profiles_file

    def load_all(self) -> dict[str, list[Profile]]:
        if not self.profiles_file.exists():
            self.save_all({})
            return {}

        try:
            data = json.loads(self.profiles_file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            logger.exception("Не удалось прочитать profiles.json")
            self.save_all({})
            return {}

        # совместимость: старый формат list
        if isinstance(data, list):
            profiles = [Profile.from_dict(item) for item in data]
            for profile in profiles:
                profile.mods_path = normalize_windows_path(profile.mods_path)
            return {LEGACY_KEY: profiles}

        if not isinstance(data, dict):
            self.save_all({})
            return {}

        result: dict[str, list[Profile]] = {}
        for game_id, raw_profiles in data.items():
            if not isinstance(raw_profiles, list):
                result[str(game_id)] = []
                continue
            profiles = [Profile.from_dict(item) for item in raw_profiles]
            for profile in profiles:
                profile.mods_path = normalize_windows_path(profile.mods_path)
            result[str(game_id)] = profiles

        return result

    def save_all(self, profiles_by_game: dict[str, Iterable[Profile]]) -> None:
        payload = {game_id: [p.to_dict() for p in profiles] for game_id, profiles in profiles_by_game.items()}
        self.profiles_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    def create_profile(self, name: str, mods_path: str) -> Profile:
        return Profile(id=str(uuid4()), name=name.strip(), mods_path=normalize_windows_path(mods_path))
