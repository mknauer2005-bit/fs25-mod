from __future__ import annotations

import json
import logging
from pathlib import Path
from uuid import uuid4

from app.models.game_profile import GameProfile

logger = logging.getLogger(__name__)


class GameService:
    def __init__(self, games_file: Path) -> None:
        self.games_file = games_file

    def load(self) -> list[GameProfile]:
        if not self.games_file.exists():
            self.save([])
            return []

        try:
            data = json.loads(self.games_file.read_text(encoding="utf-8"))
            raw_games = data if isinstance(data, list) else []
            games = [GameProfile.from_dict(item) for item in raw_games]
        except (json.JSONDecodeError, OSError):
            logger.exception("Не удалось прочитать games.json")
            games = []
            self.save(games)

        return games

    def save(self, games: list[GameProfile]) -> None:
        payload = [g.to_dict() for g in games]
        self.games_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    def create_game_profile(self, name: str) -> GameProfile:
        game = GameProfile(id=str(uuid4()), name=name.strip())
        game.normalize_paths()
        return game
