import shutil
import subprocess


def build_windows():
    # 1. Экспорт Godot
    subprocess.run(
        [
            "C:/Games/Godot Engine/Godot_v4.7-stable_win64.exe",
            "--headless",
            "--path ./ProceduralTextureEditor",
            "--export-release",
            "Windows",  # "Windows Desktop"
            "build/windows/program.exe",
        ]
    )

    subprocess.run(
        [
            "pyinstaller",
            "--onefile",
            "--name",
            "python_server",
            "ProceduralTextureEditor/GENERATOR/main.py",
        ]
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
start "" program.exe
""")


build_windows()
