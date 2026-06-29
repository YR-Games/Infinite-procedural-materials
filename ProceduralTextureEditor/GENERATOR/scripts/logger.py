"""Настройка логирования."""

import logging
import shutil
import sys
from datetime import datetime
from pathlib import Path

lib_logger = logging.getLogger("lib")

main_module = sys.modules["__main__"]
assert main_module is not None and main_module.__file__ is not None

main_dir: Path = Path(main_module.__file__).resolve().parent
log_dir: Path = main_dir / "logs"
if log_dir.exists():
    shutil.rmtree(log_dir)
log_dir.mkdir(parents=True, exist_ok=True)

formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

file_handler = logging.FileHandler(
    f"{log_dir}/{datetime.now().strftime('%Y%m%d_%H%M%S')}.log", encoding="utf-8"
)
file_handler.setFormatter(formatter)
file_handler.setLevel(logging.DEBUG)
lib_logger.addHandler(file_handler)

stream_handler = logging.StreamHandler()
stream_handler.setFormatter(formatter)
stream_handler.setLevel(logging.DEBUG)
lib_logger.addHandler(stream_handler)
lib_logger.propagate = False
