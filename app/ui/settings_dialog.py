from __future__ import annotations

import tkinter as tk
from tkinter import filedialog, ttk

from app.models.settings import Settings


class SettingsDialog(tk.Toplevel):
    def __init__(self, master: tk.Misc, settings: Settings, data_dir: str) -> None:
        super().__init__(master)
        self.title("Настройки")
        self.resizable(False, False)
        self.transient(master)
        self.grab_set()

        self.result: Settings | None = None
        self.data_dir = data_dir

        self.settings_dir_var = tk.StringVar(value=settings.game_settings_dir)
        self.exe_path_var = tk.StringVar(value=settings.game_exe_path)
        self.backup_var = tk.BooleanVar(value=settings.backup_enabled)
        self.warn_var = tk.BooleanVar(value=settings.warn_if_game_running)
        self.launch_var = tk.BooleanVar(value=settings.launch_game_after_activation)

        frame = ttk.Frame(self, padding=12)
        frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(frame, text="Раздел 1. Пути", font=("Segoe UI", 10, "bold")).grid(row=0, column=0, sticky="w")
        ttk.Entry(frame, textvariable=self.settings_dir_var, width=60).grid(row=1, column=0, pady=(2, 4), sticky="ew")
        ttk.Button(frame, text="Выбрать папку настроек FS25", command=self._choose_settings_dir).grid(row=1, column=1, padx=6)

        ttk.Entry(frame, textvariable=self.exe_path_var, width=60).grid(row=2, column=0, pady=(2, 4), sticky="ew")
        ttk.Button(frame, text="Выбрать EXE", command=self._choose_exe).grid(row=2, column=1, padx=6)

        ttk.Label(frame, text="Раздел 2. Поведение", font=("Segoe UI", 10, "bold")).grid(row=3, column=0, sticky="w", pady=(8, 2))
        ttk.Checkbutton(frame, text="Создавать backup перед записью", variable=self.backup_var).grid(row=4, column=0, sticky="w")
        ttk.Checkbutton(frame, text="Показывать предупреждение, если игра запущена", variable=self.warn_var).grid(row=5, column=0, sticky="w")
        ttk.Checkbutton(frame, text="Запускать игру после активации профиля", variable=self.launch_var).grid(row=6, column=0, sticky="w")

        ttk.Label(frame, text="Раздел 3. Данные", font=("Segoe UI", 10, "bold")).grid(row=7, column=0, sticky="w", pady=(8, 2))
        ttk.Label(frame, text=f"Папка данных: {self.data_dir}").grid(row=8, column=0, sticky="w")
        ttk.Button(frame, text="Открыть папку данных", command=self._open_data_dir).grid(row=8, column=1, sticky="e")

        buttons = ttk.Frame(frame)
        buttons.grid(row=9, column=0, columnspan=2, sticky="e", pady=(10, 0))
        ttk.Button(buttons, text="Сохранить", command=self._save).pack(side=tk.LEFT, padx=(0, 6))
        ttk.Button(buttons, text="Отмена", command=self.destroy).pack(side=tk.LEFT)

    def _choose_settings_dir(self) -> None:
        value = filedialog.askdirectory(parent=self, title="Папка с gameSettings.xml")
        if value:
            self.settings_dir_var.set(value)

    def _choose_exe(self) -> None:
        value = filedialog.askopenfilename(
            parent=self,
            title="Путь к игре",
            filetypes=[("EXE", "*.exe"), ("Все файлы", "*.*")],
        )
        if value:
            self.exe_path_var.set(value)

    def _open_data_dir(self) -> None:
        import os

        os.startfile(self.data_dir)  # type: ignore[attr-defined]

    def _save(self) -> None:
        self.result = Settings(
            game_settings_dir=self.settings_dir_var.get().strip(),
            game_settings_file="",
            game_exe_path=self.exe_path_var.get().strip(),
            backup_enabled=self.backup_var.get(),
            warn_if_game_running=self.warn_var.get(),
            launch_game_after_activation=self.launch_var.get(),
        )
        self.destroy()
