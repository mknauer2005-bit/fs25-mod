from __future__ import annotations

import tkinter as tk
from tkinter import ttk

from app.models.profile import Profile


class ProfileCard(tk.Frame):
    ACTIVE_BG = "#dff5df"

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
        bg_color = self.ACTIVE_BG if profile.is_active else "#f0f0f0"
        super().__init__(master, bd=1, relief="solid", bg=bg_color, padx=12, pady=10)
        self.profile = profile

        self.grid_columnconfigure(0, weight=1)
        self.grid_columnconfigure(1, weight=0)

        left = tk.Frame(self, bg=bg_color)
        left.grid(row=0, column=0, sticky="nsew", padx=(0, 12))

        title = f"{profile.name}"
        if profile.is_active:
            title += "  [АКТИВЕН]"

        tk.Label(left, text=title, bg=bg_color, anchor="w", font=("Segoe UI", 10, "bold")).pack(fill="x", anchor="w")
        tk.Label(left, text=f"Статус: {profile_status}", bg=bg_color, anchor="w").pack(fill="x", anchor="w", pady=(3, 0))
        tk.Label(left, text=f"Путь: {profile.mods_path}", bg=bg_color, anchor="w").pack(fill="x", anchor="w", pady=(3, 0))
        tk.Label(left, text=f"Последняя активация: {profile.last_activated_at or '—'}", bg=bg_color, anchor="w").pack(fill="x", anchor="w", pady=(3, 0))
        tk.Label(left, text=f"Состав модов: {mods_status}", bg=bg_color, anchor="w").pack(fill="x", anchor="w", pady=(3, 0))

        right = ttk.Frame(self)
        right.grid(row=0, column=1, sticky="ne")

        ttk.Button(
            right,
            text="Активен" if profile.is_active else "Активировать",
            command=on_activate,
            state=tk.DISABLED if profile.is_active else tk.NORMAL,
        ).pack(anchor="e", fill="x", pady=(0, 5))
        ttk.Button(right, text="Изменить", command=on_edit).pack(anchor="e", fill="x", pady=(0, 5))
        ttk.Button(right, text="Удалить", command=on_delete).pack(anchor="e", fill="x", pady=(0, 5))
        ttk.Button(right, text="Открыть папку", command=on_open).pack(anchor="e", fill="x")
