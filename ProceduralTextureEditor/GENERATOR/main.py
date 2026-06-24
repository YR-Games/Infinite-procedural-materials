"""
main.py
Файл, управляющий вебсокетом и обеспечивающий программный интерфейс
для работы с графом и создание м жмбеддингов.
"""

import asyncio
import json
from typing import Any

import websockets

from core import get_next_params_set


# Вспомогательные функции
def process_rendering(params):
    """
    Генерирует параметры и регистрирует полученные по ним рендеры до тех пор,
    пока их не будет достаточно.
    """
    while True:
        send_sucsess(get_next_params_set(params))


def send_sucsess(data: dict):
    response: dict[str, Any] = {
        "status": "success",
        "params": data,
    }


# ВебСокет
# Словарь для хранения подключенных клиентов (если нужно несколько)
connected_clients = set()
# ??? Нужно чтоб для каждого подключения была возможность хранить кеш в течении 8 часов
# или пока соединение не будет разорвано!


async def handle_client(websocket, path):
    """Обрабатывает сообщения от одного подключенного клиента."""

    # Добавляем клиента в список

    connected_clients.add(websocket)

    print(f"Клиент подключен. Всего клиентов: {len(connected_clients)}")

    try:
        # Бесконечный цикл для приема сообщений от этого клиента

        async for message in websocket:
            print(f"Получено от Godot: {message}")

            # --- ЛОГИКА ОБРАБОТКИ ---

            # Здесь вы вставляете вашу систему подбора параметров по изображению

            # Предположим, мы получаем JSON с запросом

            try:
                data = json.loads(message)

                if data.get("action") == "generate":
                    # Имитация обработки: просто отправляем обратно те же данные

                    response = process_rendering(message)
                else:
                    response = {"status": "error", "message": "Unknown action"}

            except json.JSONDecodeError:
                response = {"status": "error", "message": "Invalid JSON"}

            # Отправляем ответ обратно клиенту (Godot)
            await websocket.send(json.dumps(response))

            print(f"Отправлено в Godot: {response}")

    except websockets.ConnectionClosed:
        print("Клиент отключился.")

    finally:
        # Убираем клиента из списка при отключении
        connected_clients.remove(websocket)


async def main():
    # Запускаем сервер на localhost и порту 8765
    async with websockets.serve(handle_client, "localhost", 8765):
        print("WebSocket сервер запущен на ws://localhost:8765")

        await asyncio.Future()  # Бесконечно ожидаем


if __name__ == "__main__":
    asyncio.run(main())
