from __future__ import annotations

import tkinter as tk
from tkinter import filedialog, ttk

from app.models.game_profile import GameProfile


class GameProfileDialog(tk.Toplevel):
    def __init__(self, master: tk.Misc, game: GameProfile | None = None) -> None:
        super().__init__(master)
        self.title("Профиль игры")
        self.resizable(False, False)
        self.transient(master)
        self.grab_set()

        self.result: dict[str, str] | None = None

        self.name_var = tk.StringVar(value=game.name if game else "")
        self.settings_dir_var = tk.StringVar(value=game.game_settings_dir if game else "")
        self.exe_var = tk.StringVar(value=game.game_exe_path if game else "")
        self.launch_type_var = tk.StringVar(value=game.launch_type if game else "steam")
        self.steam_app_id_var = tk.StringVar(value=game.steam_app_id or "2300320" if game else "2300320")

        frame = ttk.Frame(self, padding=12)
        frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(frame, text="Название игры").grid(row=0, column=0, sticky="w")
        ttk.Entry(frame, textvariable=self.name_var, width=50).grid(row=1, column=0, columnspan=2, sticky="ew", pady=(2, 8))

        ttk.Label(frame, text="Папка с gameSettings.xml").grid(row=2, column=0, sticky="w")
        ttk.Entry(frame, textvariable=self.settings_dir_var, width=50).grid(row=3, column=0, sticky="ew", pady=(2, 8))
        ttk.Button(frame, text="Выбрать", command=self._pick_settings_dir).grid(row=3, column=1, padx=6)

        ttk.Label(frame, text="Путь к EXE").grid(row=4, column=0, sticky="w")
        ttk.Entry(frame, textvariable=self.exe_var, width=50).grid(row=5, column=0, sticky="ew", pady=(2, 8))
        ttk.Button(frame, text="Выбрать", command=self._pick_exe).grid(row=5, column=1, padx=6)

        ttk.Label(frame, text="Тип запуска").grid(row=6, column=0, sticky="w")
        launch_combo = ttk.Combobox(frame, textvariable=self.launch_type_var, state="readonly", values=["steam", "exe"], width=12)
        launch_combo.grid(row=7, column=0, sticky="w", pady=(2, 8))

        ttk.Label(frame, text="Steam App ID (если steam)").grid(row=8, column=0, sticky="w")
        ttk.Entry(frame, textvariable=self.steam_app_id_var, width=20).grid(row=9, column=0, sticky="w", pady=(2, 8))

        buttons = ttk.Frame(frame)
        buttons.grid(row=10, column=0, columnspan=2, sticky="e")
        ttk.Button(buttons, text="Сохранить", command=self._save).pack(side=tk.LEFT, padx=(0, 6))
        ttk.Button(buttons, text="Отмена", command=self.destroy).pack(side=tk.LEFT)

    def _pick_settings_dir(self) -> None:
        value = filedialog.askdirectory(parent=self, title="Папка с gameSettings.xml")
        if value:
            self.settings_dir_var.set(value)

    def _pick_exe(self) -> None:
        value = filedialog.askopenfilename(parent=self, title="Путь к игре", filetypes=[("EXE", "*.exe"), ("Все файлы", "*.*")])
        if value:
            self.exe_var.set(value)

    def _save(self) -> None:
        name = self.name_var.get().strip()
        if not name:
            return
        self.result = {
            "name": name,
            "game_settings_dir": self.settings_dir_var.get().strip(),
            "game_exe_path": self.exe_var.get().strip(),
            "launch_type": self.launch_type_var.get().strip() or "steam",
            "steam_app_id": self.steam_app_id_var.get().strip(),
        }
        self.destroy()
