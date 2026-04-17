# FS25 Mod Profiles Manager (Windows)

Готовое Windows-приложение на Python для управления профилями папок модов Farming Simulator 25.

## Возможности MVP

- Хранит настройки и профили отдельно от игры.
- Создаёт/редактирует/удаляет профили.
- Активирует профиль через XML-парсинг `gameSettings.xml` (тег `modsDirectoryOverride`).
- Перед записью делает backup (если включено).
- Проверяет запись повторным чтением XML.
- Показывает статус активного профиля и путь модов из XML.
- Проверяет состав папки модов: все ZIP или есть папки.
- Проверяет, запущена ли игра, и показывает предупреждение.
- Может запустить игру по пути к EXE.

## Установка и запуск (Windows)

```bat
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python -m app.main
```

## Сборка в EXE (PyInstaller)

Быстрая сборка одной командой:

```bat
pyinstaller --name FS25ModProfilesManager --windowed --clean --noconfirm app\main.py
```

Готовый EXE будет в папке `dist\FS25ModProfilesManager\`.

## Где лежат данные приложения

Приложение автоматически создаёт:

- `%LOCALAPPDATA%\FS25ModProfilesManager\settings.json`
- `%LOCALAPPDATA%\FS25ModProfilesManager\profiles.json`
- `%LOCALAPPDATA%\FS25ModProfilesManager\backups\`
- `%LOCALAPPDATA%\FS25ModProfilesManager\app.log`

## Проверка XML

Приложение:

1. читает `gameSettings.xml`;
2. находит/создаёт `modsDirectoryOverride`;
3. оставляет только один рабочий тег;
4. ставит `active="true"`;
5. записывает путь в `directory`;
6. перечитывает файл и подтверждает запись.
