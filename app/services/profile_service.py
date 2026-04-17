from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Iterable
from uuid import uuid4

from app.models.profile import Profile
from app.utils.paths import normalize_windows_path

logger = logging.getLogger(__name__)


class ProfileService:
    def __init__(self, profiles_file: Path) -> None:
        self.profiles_file = profiles_file

    def load(self) -> list[Profile]:
        if not self.profiles_file.exists():
            self.save([])
            return []

        try:
            data = json.loads(self.profiles_file.read_text(encoding="utf-8"))
            raw_profiles = data if isinstance(data, list) else []
            profiles = [Profile.from_dict(item) for item in raw_profiles]
        except (json.JSONDecodeError, OSError) as exc:
            logger.exception("Не удалось прочитать profiles.json")
            profiles = []
            self.save(profiles)

        for profile in profiles:
            profile.mods_path = normalize_windows_path(profile.mods_path)
        return profiles

    def save(self, profiles: Iterable[Profile]) -> None:
        payload = [p.to_dict() for p in profiles]
        self.profiles_file.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def create_profile(self, name: str, mods_path: str) -> Profile:
        return Profile(id=str(uuid4()), name=name.strip(), mods_path=normalize_windows_path(mods_path))
