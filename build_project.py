import shutil
import subprocess


def build_windows():
    # 1. Экспорт Godot
    subprocess.run(
        ["godot", "--headless", "--export-release", "Windows", "build/windows/game.exe"]
    )

    # 2. Упаковка Python
    subprocess.run(
        ["pyinstaller", "--onefile", "--name", "python_server", "python_server/main.py"]
    )

    # 3. Копирование
    shutil.copy("dist/python_server.exe", "build/windows/")

    # 4. Создание лаунчера
    create_launcher("build/windows/")


def create_launcher(path: str):
    with open(f"{path}/start.bat", "w") as f:
        f.write("""@echo off
start "" python_server.exe
timeout /t 2
start "" game.exe
""")
