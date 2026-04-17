from __future__ import annotations

import tkinter as tk
from pathlib import Path
from tkinter import filedialog, ttk

from app.models.profile import Profile


class ProfileDialog(tk.Toplevel):
    def __init__(self, master: tk.Misc, existing_paths: set[str], profile: Profile | None = None) -> None:
        super().__init__(master)
        self.title("Профиль")
        self.resizable(False, False)
        self.transient(master)
        self.grab_set()

        self._existing_paths = {p.lower() for p in existing_paths}
        self.result: tuple[str, str] | None = None

        self.name_var = tk.StringVar(value=profile.name if profile else "")
        self.path_var = tk.StringVar(value=profile.mods_path if profile else "")
        self.validation_var = tk.StringVar(value="")

        frame = ttk.Frame(self, padding=12)
        frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(frame, text="Имя профиля").grid(row=0, column=0, sticky="w")
        ttk.Entry(frame, textvariable=self.name_var, width=48).grid(row=1, column=0, columnspan=3, sticky="ew", pady=(2, 8))

        ttk.Label(frame, text="Папка модов").grid(row=2, column=0, sticky="w")
        ttk.Entry(frame, textvariable=self.path_var, width=48).grid(row=3, column=0, sticky="ew", pady=(2, 8))
        ttk.Button(frame, text="Выбрать папку", command=self._choose_folder).grid(row=3, column=1, padx=6)
        ttk.Button(frame, text="Открыть", command=self._open_folder).grid(row=3, column=2)

        ttk.Label(frame, textvariable=self.validation_var, foreground="#0a7a24").grid(row=4, column=0, columnspan=3, sticky="w")

        btn_frame = ttk.Frame(frame)
        btn_frame.grid(row=5, column=0, columnspan=3, sticky="e", pady=(10, 0))
        ttk.Button(btn_frame, text="Сохранить", command=self._save).pack(side=tk.LEFT, padx=(0, 6))
        ttk.Button(btn_frame, text="Отмена", command=self.destroy).pack(side=tk.LEFT)

        self.path_var.trace_add("write", lambda *_: self._update_validation())
        self._update_validation()

    def _choose_folder(self) -> None:
        path = filedialog.askdirectory(parent=self, title="Выберите папку модов")
        if path:
            self.path_var.set(path)

    def _open_folder(self) -> None:
        path = self.path_var.get().strip()
        if path and Path(path).exists():
            import os

            os.startfile(path)  # type: ignore[attr-defined]

    def _update_validation(self) -> None:
        path = self.path_var.get().strip()
        if not path:
            self.validation_var.set("Укажите путь к папке модов")
            return

        folder = Path(path)
        if not folder.exists():
            self.validation_var.set("Папка не найдена")
            return
        if not folder.is_dir():
            self.validation_var.set("Это не папка")
            return

        try:
            items = list(folder.iterdir())
        except OSError:
            self.validation_var.set("Папка недоступна")
            return

        msg = "Папка найдена"
        if not items:
            msg += ", папка пуста"

        if path.lower() in self._existing_paths:
            msg += ", путь уже используется в другом профиле"

        self.validation_var.set(msg)

    def _save(self) -> None:
        name = self.name_var.get().strip()
        path = self.path_var.get().strip()
        if not name or not path:
            self.validation_var.set("Заполните имя и путь")
            return
        self.result = (name, path)
        self.destroy()
