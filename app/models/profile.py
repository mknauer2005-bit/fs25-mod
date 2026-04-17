from __future__ import annotations

from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Any


@dataclass
class Profile:
    id: str
    name: str
    mods_path: str
    is_active: bool = False
    last_activated_at: str | None = None

    def mark_activated(self) -> None:
        self.is_active = True
        self.last_activated_at = datetime.now().isoformat(timespec="seconds")

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Profile":
        return cls(
            id=str(data.get("id", "")),
            name=str(data.get("name", "")),
            mods_path=str(data.get("mods_path", "")),
            is_active=bool(data.get("is_active", False)),
            last_activated_at=data.get("last_activated_at"),
        )
