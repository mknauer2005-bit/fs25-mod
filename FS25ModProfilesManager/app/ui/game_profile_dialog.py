from __future__ import annotations

import tkinter as tk
from pathlib import Path
from tkinter import filedialog, ttk

from app.models.game_profile import GameProfile


class GameProfileDialog(tk.Toplevel):
    LAUNCH_LABEL_TO_TYPE = {
        "Steam": "steam",
        "Epic": "epic",
        "Пиратка": "pirate",
    }
    LAUNCH_TYPE_TO_LABEL = {v: k for k, v in LAUNCH_LABEL_TO_TYPE.items()}

    STEAM_APP_IDS = {
        "fs25": "2300320",
        "fs22": "1248130",
        "fs19": "787860",
        "fs17": "447020",
    }

    DETECT_RULES = [
        ("fs25", ["farmingsimulator2025", "farming simulator 25", "fs25", "2025"]),
        ("fs22", ["farmingsimulator2022", "farming simulator 22", "fs22", "2022"]),
        ("fs19", ["farmingsimulator2019", "farming simulator 19", "fs19", "2019"]),
        ("fs17", ["farmingsimulator2017", "farming simulator 17", "fs17", "2017"]),
    ]

    def __init__(self, master: tk.Misc, game: GameProfile | None = None) -> None:
        super().__init__(master)
        self.title("Профиль игры")
        self.resizable(False, False)
        self.transient(master)
        self.grab_set()

        self.result: dict[str, str] | None = None
        self._last_auto_app_id = ""
        self._steam_app_id_manual = False

        launch_label = self.LAUNCH_TYPE_TO_LABEL.get(game.launch_type if game else "steam", "Steam")

        self.name_var = tk.StringVar(value=game.name if game else "")
        self.settings_dir_var = tk.StringVar(value=game.game_settings_dir if game else "")
        self.exe_var = tk.StringVar(value=game.game_exe_path if game else "")
        self.launch_type_label_var = tk.StringVar(value=launch_label)
        self.steam_app_id_var = tk.StringVar(value=game.steam_app_id or "" if game else "")

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
        self.launch_combo = ttk.Combobox(
            frame,
            textvariable=self.launch_type_label_var,
            state="readonly",
            values=list(self.LAUNCH_LABEL_TO_TYPE.keys()),
            width=12,
        )
        self.launch_combo.grid(row=7, column=0, sticky="w", pady=(2, 8))

        ttk.Label(frame, text="Steam App ID (только для Steam)").grid(row=8, column=0, sticky="w")
        self.steam_entry = ttk.Entry(frame, textvariable=self.steam_app_id_var, width=20)
        self.steam_entry.grid(row=9, column=0, sticky="w", pady=(2, 8))

        buttons = ttk.Frame(frame)
        buttons.grid(row=10, column=0, columnspan=2, sticky="e")
        ttk.Button(buttons, text="Сохранить", command=self._save).pack(side=tk.LEFT, padx=(0, 6))
        ttk.Button(buttons, text="Отмена", command=self.destroy).pack(side=tk.LEFT)

        self.launch_combo.bind("<<ComboboxSelected>>", lambda _: self._on_launch_type_changed())
        self.name_var.trace_add("write", lambda *_: self._auto_fill_steam_app_id())
        self.exe_var.trace_add("write", lambda *_: self._auto_fill_steam_app_id())
        self.steam_app_id_var.trace_add("write", self._on_steam_app_id_changed)

        self._update_steam_field_state()
        self._auto_fill_steam_app_id()

    def _pick_settings_dir(self) -> None:
        value = filedialog.askdirectory(parent=self, title="Папка с gameSettings.xml")
        if value:
            self.settings_dir_var.set(value)

    def _pick_exe(self) -> None:
        value = filedialog.askopenfilename(parent=self, title="Путь к игре", filetypes=[("EXE", "*.exe"), ("Все файлы", "*.*")])
        if value:
            self.exe_var.set(value)

    def _launch_type(self) -> str:
        return self.LAUNCH_LABEL_TO_TYPE.get(self.launch_type_label_var.get(), "steam")

    def _on_launch_type_changed(self) -> None:
        self._update_steam_field_state()
        self._auto_fill_steam_app_id(force_if_empty=True)

    def _update_steam_field_state(self) -> None:
        launch_type = self._launch_type()
        if launch_type == "steam":
            self.steam_entry.configure(state="normal")
            return

        self._steam_app_id_manual = False
        self._last_auto_app_id = ""
        self.steam_app_id_var.set("")
        self.steam_entry.configure(state="disabled")

    def _on_steam_app_id_changed(self, *_args) -> None:
        if self._launch_type() != "steam":
            return
        current = self.steam_app_id_var.get().strip()
        if current and current != self._last_auto_app_id:
            self._steam_app_id_manual = True

    def _detect_steam_app_id(self) -> str:
        exe_path = self.exe_var.get().strip().lower()
        exe_name = Path(exe_path).name.lower() if exe_path else ""
        game_name = self.name_var.get().strip().lower()

        haystack = " ".join([exe_path, exe_name, game_name])
        for key, patterns in self.DETECT_RULES:
            if any(pattern in haystack for pattern in patterns):
                return self.STEAM_APP_IDS[key]
        return ""

    def _auto_fill_steam_app_id(self, force_if_empty: bool = False) -> None:
        if self._launch_type() != "steam":
            return

        detected = self._detect_steam_app_id()
        if not detected:
            return

        current = self.steam_app_id_var.get().strip()
        if self._steam_app_id_manual and current and current != self._last_auto_app_id:
            return
        if current and not force_if_empty and current != self._last_auto_app_id:
            return

        self._last_auto_app_id = detected
        self.steam_app_id_var.set(detected)

    def _save(self) -> None:
        name = self.name_var.get().strip()
        if not name:
            return

        launch_type = self._launch_type()
        steam_id = self.steam_app_id_var.get().strip() if launch_type == "steam" else ""

        self.result = {
            "name": name,
            "game_settings_dir": self.settings_dir_var.get().strip(),
            "game_exe_path": self.exe_var.get().strip(),
            "launch_type": launch_type,
            "steam_app_id": steam_id,
        }
        self.destroy()
