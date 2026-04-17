from __future__ import annotations

from pathlib import Path

from app.models.game_profile import GameProfile
from app.models.profile import Profile
from app.services.backup_service import BackupService
from app.utils.xml_helpers import read_mods_override, upsert_mods_override


class ConfigService:
    GAME_SETTINGS_FILENAME = "gameSettings.xml"

    def __init__(self, backup_service: BackupService) -> None:
        self.backup_service = backup_service

    @classmethod
    def resolve_game_settings_file(cls, settings_dir: str) -> Path:
        return Path(settings_dir) / cls.GAME_SETTINGS_FILENAME

    def apply_profile(
        self,
        game_profile: GameProfile,
        profiles: list[Profile],
        profile_id: str,
        backup_enabled: bool,
    ) -> tuple[Profile, str | None]:
        selected = next((p for p in profiles if p.id == profile_id), None)
        if selected is None:
            raise ValueError("Профиль не найден")

        xml_path = Path(game_profile.game_settings_file)
        if not xml_path.exists():
            raise FileNotFoundError("gameSettings.xml не найден")

        mods_dir = Path(selected.mods_path)
        if not mods_dir.exists() or not mods_dir.is_dir():
            raise FileNotFoundError("Папка профиля не найдена")

        backup_path = None
        if backup_enabled:
            backup = self.backup_service.create_backup(xml_path)
            backup_path = str(backup)

        upsert_mods_override(xml_path, selected.mods_path)

        applied = read_mods_override(xml_path)
        if applied != selected.mods_path:
            raise RuntimeError("Путь модов не применился")

        for p in profiles:
            p.is_active = False
        selected.mark_activated()

        return selected, backup_path
