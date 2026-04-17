from __future__ import annotations

import tkinter as tk
from tkinter import ttk

from app.models.profile import Profile


class ProfileCard(ttk.Frame):
    def __init__(
        self,
        master: tk.Misc,
        profile: Profile,
        profile_status: str,
        mods_status: str,
        on_activate,
        on_edit,
        on_delete,
        on_open,
    ) -> None:
        super().__init__(master, padding=8, relief="solid", borderwidth=1)
        self.profile = profile

        title = f"{profile.name}"
        if profile.is_active:
            title += "  [АКТИВЕН]"
        ttk.Label(self, text=title, font=("Segoe UI", 10, "bold")).grid(row=0, column=0, sticky="w")
        ttk.Label(self, text=f"Статус: {profile_status}").grid(row=1, column=0, sticky="w")
        ttk.Label(self, text=f"Путь: {profile.mods_path}").grid(row=2, column=0, sticky="w")
        ttk.Label(self, text=f"Последняя активация: {profile.last_activated_at or '—'}").grid(row=3, column=0, sticky="w")
        ttk.Label(self, text=f"Состав модов: {mods_status}").grid(row=4, column=0, sticky="w")

        btn_row = ttk.Frame(self)
        btn_row.grid(row=5, column=0, sticky="w", pady=(6, 0))
        ttk.Button(
            btn_row,
            text="Активен" if profile.is_active else "Активировать",
            command=on_activate,
            state=tk.DISABLED if profile.is_active else tk.NORMAL,
        ).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(btn_row, text="Изменить", command=on_edit).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(btn_row, text="Удалить", command=on_delete).pack(side=tk.LEFT, padx=(0, 5))
        ttk.Button(btn_row, text="Открыть папку", command=on_open).pack(side=tk.LEFT)
