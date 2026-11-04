"""
scripts/net.py
Предоставляет все необходимые функции для работы с сетью: распознавание сообщений, управление подключениями и тп.
"""

import socket

from .logger import lib_logger


class ConnectionManager:
    def __init__(self, host: str = "127.0.0.1", port: int = 12345) -> None:
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((host, port))
        server.listen(1)
        lib_logger.info(f"Generator listening on {host}:{port}")


# ??? Вынести сюда функции управления соединением!

"""
CPU-тяжёлая обработка (ресайз, хэш, запись в БД) — оборачивайте в await asyncio.to_thread(...)

В проде использовать потоковое чтение!
"""
