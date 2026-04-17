from __future__ import annotations

from app.ui.main_window import MainWindow
from app.utils.logging_config import setup_logging
from app.utils.paths import ensure_data_structure


def main() -> None:
    paths = ensure_data_structure()
    setup_logging(paths["log"])
    app = MainWindow()
    app.mainloop()


if __name__ == "__main__":
    main()
