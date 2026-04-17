from __future__ import annotations

import logging
import os
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from app.models.app_state import AppState
from app.models.game_profile import GameProfile
from app.models.profile import Profile
from app.models.settings import Settings
from app.services.backup_service import BackupService
from app.services.config_service import ConfigService
from app.services.game_launcher import GameLauncher
from app.services.game_service import GameService
from app.services.mod_folder_validator import ModFolderValidator
from app.services.process_service import ProcessService
from app.services.profile_service import LEGACY_KEY, ProfileService
from app.services.settings_service import SettingsService
from app.ui.game_profile_dialog import GameProfileDialog
from app.ui.profile_dialog import ProfileDialog
from app.ui.settings_dialog import SettingsDialog
from app.ui.widgets.profile_card import ProfileCard
from app.utils.paths import ensure_data_structure, normalize_windows_path
from app.utils.validators import is_existing_file
from app.utils.xml_helpers import XmlError, read_mods_override

logger = logging.getLogger(__name__)


class MainWindow(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("FS25 Менеджер профилей модов")
        self.geometry("1180x780")

        self.paths = ensure_data_structure()
        self.settings_service = SettingsService(self.paths["settings"])
        self.game_service = GameService(self.paths["games"])
        self.profile_service = ProfileService(self.paths["profiles"])
        self.backup_service = BackupService(self.paths["backups"])
        self.config_service = ConfigService(self.backup_service)

        self.settings = self.settings_service.load()
        self.games = self.game_service.load()
        self.profiles_by_game = self.profile_service.load_all()
        self.profiles: list[Profile] = []
        self.current_game: GameProfile | None = None
        self.state = AppState()

        self._migrate_legacy_if_needed()
        self._init_ui()
        self._load_selected_game_into_ui()
        self.refresh_state()

    def _migrate_legacy_if_needed(self) -> None:
        if self.games:
            if self.settings.selected_game_id and any(g.id == self.settings.selected_game_id for g in self.games):
                return
            self.settings.selected_game_id = self.games[0].id
            self.settings_service.save(self.settings)
            return

        default_game = GameProfile(
            id="fs25_default",
            name="FS25",
            game_settings_dir=self.settings.game_settings_dir,
            game_settings_file=self.settings.game_settings_file,
            game_exe_path=self.settings.game_exe_path,
            launch_type="steam",
            steam_app_id="2300320",
        )
        default_game.normalize_paths()
        self.games = [default_game]

        legacy_profiles = self.profiles_by_game.pop(LEGACY_KEY, [])
        self.profiles_by_game[default_game.id] = legacy_profiles

        self.settings.selected_game_id = default_game.id
        self.game_service.save(self.games)
        self.profile_service.save_all(self.profiles_by_game)
        self.settings_service.save(self.settings)

    def _init_ui(self) -> None:
        root = ttk.Frame(self, padding=10)
        root.pack(fill=tk.BOTH, expand=True)

        self._build_game_selector(root)
        self._build_paths_block(root)
        self._build_status_block(root)
        self._build_profiles_block(root)
        self._build_bottom_panel(root)

    def _build_game_selector(self, parent: ttk.Frame) -> None:
        frame = ttk.LabelFrame(parent, text="Текущая игра", padding=10)
        frame.pack(fill=tk.X)

        self.game_selector_var = tk.StringVar()
        self.game_selector = ttk.Combobox(frame, textvariable=self.game_selector_var, state="readonly", width=40)
        self.game_selector.pack(side=tk.LEFT, padx=(0, 8))
        self.game_selector.bind("<<ComboboxSelected>>", lambda _: self.on_game_changed())

        ttk.Button(frame, text="Добавить игру", command=self.add_game).pack(side=tk.LEFT, padx=4)
        ttk.Button(frame, text="Редактировать игру", command=self.edit_game).pack(side=tk.LEFT, padx=4)
        ttk.Button(frame, text="Удалить игру", command=self.delete_game).pack(side=tk.LEFT, padx=4)

    def _build_paths_block(self, parent: ttk.Frame) -> None:
        frame = ttk.LabelFrame(parent, text="Пути выбранной игры", padding=10)
        frame.pack(fill=tk.X, pady=(10, 0))

        self.settings_dir_var = tk.StringVar(value="")
        self.exe_var = tk.StringVar(value="")
        self.gs_status_var = tk.StringVar()
        self.exe_status_var = tk.StringVar()

        ttk.Label(frame, text="Папка настроек").grid(row=0, column=0, sticky="w")
        ttk.Entry(frame, textvariable=self.settings_dir_var, width=80).grid(row=1, column=0, sticky="ew")
        ttk.Button(frame, text="Выбрать", command=self.choose_settings_dir).grid(row=1, column=1, padx=4)
        ttk.Button(frame, text="Открыть", command=self.open_settings_dir).grid(row=1, column=2, padx=4)
        ttk.Label(frame, textvariable=self.gs_status_var).grid(row=1, column=3, sticky="w", padx=8)

        ttk.Label(frame, text="Путь к игре").grid(row=2, column=0, sticky="w", pady=(8, 0))
        ttk.Entry(frame, textvariable=self.exe_var, width=80).grid(row=3, column=0, sticky="ew")
        ttk.Button(frame, text="Выбрать", command=self.choose_exe).grid(row=3, column=1, padx=4)
        ttk.Button(frame, text="Открыть папку", command=self.open_exe_folder).grid(row=3, column=2, padx=4)
        ttk.Button(frame, text="Запустить игру", command=self.launch_game).grid(row=3, column=3, padx=4)
        ttk.Label(frame, textvariable=self.exe_status_var).grid(row=3, column=4, sticky="w", padx=8)

    def _build_status_block(self, parent: ttk.Frame) -> None:
        frame = ttk.LabelFrame(parent, text="Состояние", padding=10)
        frame.pack(fill=tk.X, pady=(10, 0))

        self.active_profile_var = tk.StringVar(value="—")
        self.xml_mods_var = tk.StringVar(value="—")
        self.last_act_var = tk.StringVar(value="—")
        self.state_var = tk.StringVar(value="готово")

        ttk.Label(frame, text="Текущий активный профиль:").grid(row=0, column=0, sticky="w")
        ttk.Label(frame, textvariable=self.active_profile_var).grid(row=0, column=1, sticky="w")

        ttk.Label(frame, text="Путь модов из gameSettings.xml:").grid(row=1, column=0, sticky="w")
        ttk.Label(frame, textvariable=self.xml_mods_var).grid(row=1, column=1, sticky="w")

        ttk.Label(frame, text="Время последней успешной активации:").grid(row=2, column=0, sticky="w")
        ttk.Label(frame, textvariable=self.last_act_var).grid(row=2, column=1, sticky="w")

        ttk.Label(frame, text="Общее состояние:").grid(row=3, column=0, sticky="w")
        ttk.Label(frame, textvariable=self.state_var).grid(row=3, column=1, sticky="w")

    def _build_profiles_block(self, parent: ttk.Frame) -> None:
        frame = ttk.LabelFrame(parent, text="Профили", padding=10)
        frame.pack(fill=tk.BOTH, expand=True, pady=(10, 0))

        ttk.Button(frame, text="Добавить профиль", command=self.add_profile).pack(anchor="w", pady=(0, 8))

        self.cards_canvas = tk.Canvas(frame, highlightthickness=0)
        scrollbar = ttk.Scrollbar(frame, orient="vertical", command=self.cards_canvas.yview)
        self.cards_frame = ttk.Frame(self.cards_canvas)

        self.cards_frame.bind("<Configure>", lambda e: self.cards_canvas.configure(scrollregion=self.cards_canvas.bbox("all")))

        self.cards_window_id = self.cards_canvas.create_window((0, 0), window=self.cards_frame, anchor="nw")
        self.cards_canvas.bind("<Configure>", self._on_cards_canvas_resize)
        self.cards_canvas.configure(yscrollcommand=scrollbar.set)

        self.cards_canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

    def _on_cards_canvas_resize(self, event: tk.Event) -> None:
        self.cards_canvas.itemconfigure(self.cards_window_id, width=event.width)

    def _build_bottom_panel(self, parent: ttk.Frame) -> None:
        frame = ttk.Frame(parent)
        frame.pack(fill=tk.X, pady=(10, 0))

        ttk.Button(frame, text="Создать резервную копию", command=self.create_backup_manual).pack(side=tk.LEFT, padx=(0, 6))
        ttk.Button(frame, text="Открыть папку backup", command=self.open_backup_folder).pack(side=tk.LEFT, padx=(0, 6))
        ttk.Button(frame, text="Настройки", command=self.open_settings).pack(side=tk.LEFT, padx=(0, 6))
        ttk.Button(frame, text="Обновить состояние", command=self.refresh_state).pack(side=tk.LEFT, padx=(0, 6))
        ttk.Button(frame, text="Выход", command=self.destroy).pack(side=tk.RIGHT)

    def _game_labels(self) -> list[str]:
        return [f"{g.name} ({g.id})" for g in self.games]

    def _selected_game_by_combo(self) -> GameProfile | None:
        index = self.game_selector.current()
        if index < 0 or index >= len(self.games):
            return None
        return self.games[index]

    def _load_selected_game_into_ui(self) -> None:
        self.game_selector["values"] = self._game_labels()

        selected = next((g for g in self.games if g.id == self.settings.selected_game_id), None)
        if selected is None and self.games:
            selected = self.games[0]
            self.settings.selected_game_id = selected.id

        if selected is None:
            self.current_game = None
            return

        self.current_game = selected
        idx = self.games.index(selected)
        self.game_selector.current(idx)

        self.settings_dir_var.set(selected.game_settings_dir)
        self.exe_var.set(selected.game_exe_path)
        self.profiles = self.profiles_by_game.get(selected.id, [])

    def on_game_changed(self) -> None:
        selected = self._selected_game_by_combo()
        if selected is None:
            return

        self.settings.selected_game_id = selected.id
        self.settings_service.save(self.settings)
        self._load_selected_game_into_ui()
        self.refresh_state()

    def add_game(self) -> None:
        dlg = GameProfileDialog(self)
        self.wait_window(dlg)
        if not dlg.result:
            return

        game = self.game_service.create_game_profile(dlg.result["name"])
        game.game_settings_dir = normalize_windows_path(dlg.result["game_settings_dir"])
        game.game_exe_path = normalize_windows_path(dlg.result["game_exe_path"])
        game.launch_type = dlg.result["launch_type"]
        game.steam_app_id = dlg.result["steam_app_id"] or None
        game.normalize_paths()

        self.games.append(game)
        self.profiles_by_game.setdefault(game.id, [])
        self.settings.selected_game_id = game.id

        self.game_service.save(self.games)
        self.profile_service.save_all(self.profiles_by_game)
        self.settings_service.save(self.settings)

        self._load_selected_game_into_ui()
        self.refresh_state()

    def edit_game(self) -> None:
        if not self.current_game:
            return

        dlg = GameProfileDialog(self, self.current_game)
        self.wait_window(dlg)
        if not dlg.result:
            return

        self.current_game.name = dlg.result["name"]
        self.current_game.game_settings_dir = normalize_windows_path(dlg.result["game_settings_dir"])
        self.current_game.game_exe_path = normalize_windows_path(dlg.result["game_exe_path"])
        self.current_game.launch_type = dlg.result["launch_type"]
        self.current_game.steam_app_id = dlg.result["steam_app_id"] or None
        self.current_game.normalize_paths()

        self.game_service.save(self.games)
        self._load_selected_game_into_ui()
        self.refresh_state()

    def delete_game(self) -> None:
        if not self.current_game:
            return
        if len(self.games) <= 1:
            messagebox.showerror("Ошибка", "Нельзя удалить последнюю игру")
            return

        if not messagebox.askyesno("Подтверждение", f"Удалить игру '{self.current_game.name}'?"):
            return

        game_id = self.current_game.id
        self.games = [g for g in self.games if g.id != game_id]
        self.profiles_by_game.pop(game_id, None)

        self.settings.selected_game_id = self.games[0].id

        self.game_service.save(self.games)
        self.profile_service.save_all(self.profiles_by_game)
        self.settings_service.save(self.settings)

        self._load_selected_game_into_ui()
        self.refresh_state()

    def choose_settings_dir(self) -> None:
        if not self.current_game:
            return
        path = filedialog.askdirectory(title="Выберите папку с gameSettings.xml")
        if path:
            self.current_game.game_settings_dir = normalize_windows_path(path)
            self.current_game.normalize_paths()
            self.settings_dir_var.set(self.current_game.game_settings_dir)
            self.game_service.save(self.games)
            self.refresh_state()

    def open_settings_dir(self) -> None:
        path = self.settings_dir_var.get().strip()
        if path and Path(path).exists():
            os.startfile(path)  # type: ignore[attr-defined]

    def choose_exe(self) -> None:
        if not self.current_game:
            return
        path = filedialog.askopenfilename(filetypes=[("EXE", "*.exe"), ("Все файлы", "*.*")])
        if path:
            self.current_game.game_exe_path = normalize_windows_path(path)
            self.exe_var.set(self.current_game.game_exe_path)
            self.game_service.save(self.games)
            self.refresh_state()

    def open_exe_folder(self) -> None:
        exe = self.exe_var.get().strip()
        if exe:
            folder = Path(exe).parent
            if folder.exists():
                os.startfile(str(folder))  # type: ignore[attr-defined]

    def launch_game(self) -> None:
        if not self.current_game:
            return
        try:
            GameLauncher.launch(
                game_exe_path=self.current_game.game_exe_path,
                launch_type=self.current_game.launch_type,
                steam_app_id=self.current_game.steam_app_id,
            )
        except Exception as exc:
            logger.exception("Ошибка запуска игры")
            messagebox.showerror("Ошибка", f"Ошибка запуска игры: {exc}")

    def open_backup_folder(self) -> None:
        os.startfile(str(self.paths["backups"]))  # type: ignore[attr-defined]

    def create_backup_manual(self) -> None:
        if not self.current_game:
            return
        xml = Path(self.current_game.game_settings_file)
        if not xml.exists():
            messagebox.showerror("Ошибка", "gameSettings.xml не найден")
            return
        backup = self.backup_service.create_backup(xml)
        messagebox.showinfo("Готово", f"Backup создан:\n{backup}")

    def open_settings(self) -> None:
        dlg = SettingsDialog(self, self.settings, str(self.paths["root"]))
        self.wait_window(dlg)
        if dlg.result:
            self.settings.backup_enabled = dlg.result.backup_enabled
            self.settings.warn_if_game_running = dlg.result.warn_if_game_running
            self.settings.launch_game_after_activation = dlg.result.launch_game_after_activation
            self.settings_service.save(self.settings)
            self.refresh_state()

    def add_profile(self) -> None:
        if not self.current_game:
            return
        used = {p.mods_path for p in self.profiles}
        dlg = ProfileDialog(self, used)
        self.wait_window(dlg)
        if not dlg.result:
            return
        name, path = dlg.result
        profile = self.profile_service.create_profile(name, path)
        self.profiles.append(profile)
        self.profiles_by_game[self.current_game.id] = self.profiles
        self.profile_service.save_all(self.profiles_by_game)
        self.refresh_profiles()

    def edit_profile(self, profile: Profile) -> None:
        used = {p.mods_path for p in self.profiles if p.id != profile.id}
        dlg = ProfileDialog(self, used, profile)
        self.wait_window(dlg)
        if not dlg.result:
            return
        name, path = dlg.result
        profile.name = name
        profile.mods_path = normalize_windows_path(path)
        if self.current_game:
            self.profiles_by_game[self.current_game.id] = self.profiles
        self.profile_service.save_all(self.profiles_by_game)
        self.refresh_profiles()

    def delete_profile(self, profile: Profile) -> None:
        if not messagebox.askyesno("Подтверждение", f"Удалить профиль '{profile.name}'?"):
            return
        self.profiles = [p for p in self.profiles if p.id != profile.id]
        if self.current_game:
            self.profiles_by_game[self.current_game.id] = self.profiles
        self.profile_service.save_all(self.profiles_by_game)
        self.refresh_state()

    def activate_profile(self, profile: Profile) -> None:
        if not self.current_game:
            return

        if not Path(profile.mods_path).exists():
            messagebox.showerror("Ошибка", "Папка профиля не найдена")
            return

        if self.settings.warn_if_game_running and ProcessService.is_game_running(self.current_game.game_exe_path):
            messagebox.showwarning("Предупреждение", "Игра запущена. Изменения могут примениться только после её перезапуска.")

        if not self.current_game.game_settings_dir:
            messagebox.showerror("Ошибка", "Укажите папку с gameSettings.xml")
            return

        self.current_game.normalize_paths()
        if not is_existing_file(self.current_game.game_settings_file):
            messagebox.showerror("Ошибка", "gameSettings.xml не найден")
            return

        try:
            selected, backup_path = self.config_service.apply_profile(
                game_profile=self.current_game,
                profiles=self.profiles,
                profile_id=profile.id,
                backup_enabled=self.settings.backup_enabled,
            )
            self.profiles_by_game[self.current_game.id] = self.profiles
            self.profile_service.save_all(self.profiles_by_game)
            self.game_service.save(self.games)
        except XmlError as exc:
            logger.exception("Ошибка XML")
            messagebox.showerror("Ошибка", f"Ошибка записи XML: {exc}")
            return
        except Exception as exc:
            logger.exception("Ошибка активации")
            messagebox.showerror("Ошибка", str(exc))
            return

        msg = f"Профиль '{selected.name}' активирован."
        if backup_path:
            msg += f"\nBackup: {backup_path}"
        messagebox.showinfo("Готово", msg)

        if self.settings.launch_game_after_activation:
            try:
                GameLauncher.launch(
                    game_exe_path=self.current_game.game_exe_path,
                    launch_type=self.current_game.launch_type,
                    steam_app_id=self.current_game.steam_app_id,
                )
            except Exception as exc:
                messagebox.showerror("Ошибка", f"Ошибка запуска игры: {exc}")

        self.refresh_state()

    def _sort_profiles_for_ui(self) -> None:
        self.profiles.sort(key=lambda p: (not p.is_active, p.name.lower()))

    def refresh_profiles(self) -> None:
        self._sort_profiles_for_ui()

        for child in self.cards_frame.winfo_children():
            child.destroy()

        for profile in self.profiles:
            exists = Path(profile.mods_path).is_dir()
            status = "АКТИВЕН" if profile.is_active else "НЕ АКТИВЕН"
            if not exists:
                status = "ПАПКА НЕ НАЙДЕНА"

            valid, mods_status = ModFolderValidator.validate_folder(profile.mods_path)
            if not valid:
                status = "ОШИБКА"

            card = ProfileCard(
                self.cards_frame,
                profile,
                profile_status=status,
                mods_status=mods_status,
                on_activate=lambda p=profile: self.activate_profile(p),
                on_edit=lambda p=profile: self.edit_profile(p),
                on_delete=lambda p=profile: self.delete_profile(p),
                on_open=lambda p=profile: self.open_profile_dir(p),
            )
            card.pack(fill=tk.X, padx=4, pady=6)

    def open_profile_dir(self, profile: Profile) -> None:
        path = Path(profile.mods_path)
        if path.exists():
            os.startfile(str(path))  # type: ignore[attr-defined]
        else:
            messagebox.showerror("Ошибка", "Папка профиля не найдена")

    def refresh_state(self) -> None:
        if self.current_game:
            self.current_game.game_settings_dir = normalize_windows_path(self.settings_dir_var.get().strip())
            self.current_game.game_exe_path = normalize_windows_path(self.exe_var.get().strip())
            self.current_game.normalize_paths()
            self.game_service.save(self.games)
            self.profiles = self.profiles_by_game.get(self.current_game.id, [])

            game_settings_ok = is_existing_file(self.current_game.game_settings_file)
            exe_ok = is_existing_file(self.current_game.game_exe_path)
        else:
            game_settings_ok = False
            exe_ok = False

        self.gs_status_var.set("gameSettings.xml найден" if game_settings_ok else "gameSettings.xml не найден")
        self.exe_status_var.set("EXE найден" if exe_ok else "EXE не найден")

        xml_mods = "—"
        if self.current_game:
            xml_path = Path(self.current_game.game_settings_file)
            if xml_path.exists():
                try:
                    xml_mods = read_mods_override(xml_path) or "—"
                except Exception:
                    xml_mods = "Ошибка чтения"

        for p in self.profiles:
            p.is_active = False

        matched = next((p for p in self.profiles if normalize_windows_path(p.mods_path).lower() == normalize_windows_path(xml_mods).lower()), None)
        if matched:
            matched.is_active = True

        active = next((p for p in self.profiles if p.is_active), None)
        self.active_profile_var.set(active.name if active else "—")
        self.xml_mods_var.set(xml_mods)
        self.last_act_var.set(active.last_activated_at if active and active.last_activated_at else "—")

        running = ProcessService.is_game_running(self.current_game.game_exe_path if self.current_game else "")
        status = "готово"
        if running:
            status = "игра запущена"
        if not game_settings_ok:
            status = "предупреждение"
        self.state_var.set(status)

        if self.current_game:
            self.profiles_by_game[self.current_game.id] = self.profiles
            self.profile_service.save_all(self.profiles_by_game)

        self.refresh_profiles()
