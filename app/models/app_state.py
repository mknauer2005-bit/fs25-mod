from __future__ import annotations

from dataclasses import dataclass


@dataclass
class AppState:
    active_profile_name: str = "—"
    xml_mods_path: str = "—"
    last_activation_time: str = "—"
    status: str = "готово"
    game_running: bool = False
