"""
main.py
Главный файл Генератора, управляющий вебсокетом и обеспечивающий программный интерфейс
для работы с графом и создание м жмбеддингов.

JSON Контракт:
 От Редактора:


"""

import asyncio
import json
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

import websockets
from PIL import Image
from websockets.asyncio.server import ServerConnection

# from core import add_render
from scripts.logger import lib_logger
from scripts.utils import base64_to_pil


@dataclass(slots=True)
class Message:
    action: str
    params: dict[str, Any]


@dataclass(slots=True)
class ClientSession:
    websocket: ServerConnection
    cache: dict[str, Any] = field(default_factory=dict)
    created_at: datetime = field(default_factory=datetime.now)

    render_counter: int = 0


connected_clients: dict[int, ClientSession] = {}


# Вспомогательные функции:
async def send_message(
    websocket: ServerConnection,
    msg_type: str,
    payload: dict[str, Any] | None = None,
):
    message: dict[str, Any] = {
        "type": msg_type,
        "payload": payload or {},
    }

    await websocket.send(json.dumps(message))

    lib_logger.info("Из Генератора отправлено сообщение >", message)


async def on_material_add_request(
    session: ClientSession,
    payload: dict[str, Any],
):
    print(
        "Material received"
    )  # ??? Обработка запроса init_material_adding(payload.get("material"))

    await send_message(
        session.websocket,
        "material_add_accepted",
    )

    await send_render_request(session)


async def send_render_request(
    session: ClientSession,
):
    """Запрос на генерацию и отправку нового рендера для материала."""
    session.render_counter += 1

    await send_message(
        session.websocket,
        "render_request",
        {"parameters": {"seed": session.render_counter}},
    )


async def on_render_result(
    session: ClientSession,
    payload: dict[str, Any],
):
    image: Image.Image = base64_to_pil(payload["image"])

    lib_logger.info(
        "Render result: ",
        image.size,
    )

    # далее
    # if add_render(image):
    await send_message(
        session.websocket,
        "render_accepted",
        {
            "cluster_id": session.render_counter,
        },
    )
    # else:
    #   await send_message(session.websocket, "render_rejected")

    if session.render_counter < 5:  # ??? Временно!
        await send_render_request(session)
    else:
        await send_message(
            session.websocket,
            "material_add_completed",
            {
                "clusters_added": 5,  # core.get_material_graph_nodes()
                "renders_checked": 5,
            },
        )


async def on_material_search_request(
    session: ClientSession,
    payload: dict[str, Any],
):
    image: Image.Image = base64_to_pil(payload["image"])

    lib_logger.info("Search image:", image.size)

    """??? Тестовый демонстрационный прототип!"""
    total_progress: float = 10

    async def send_progress(p: float):
        await send_message(
            session.websocket,
            "search_progress",
            {
                "checked": p,
                "total": total_progress,
            },
        )

    await send_message(
        session.websocket,
        "material_search_started",
    )

    for i in range(10):
        await asyncio.sleep(0.5)

        await send_progress(i + 1)

    for similarity in [0.95, 0.88, 0.72]:
        await send_message(
            session.websocket,
            "material_match_found",
            {
                "similarity": similarity,
                "material": {},
            },
        )

    await send_message(
        session.websocket,
        "material_search_completed",
        {
            "matches_found": 3,
        },
    )


# Основные функции:
async def process_message(
    session: ClientSession,
    data: dict[str, Any],
):
    """Диспетчер входящих сообщений."""
    msg_type = data.get("type")
    payload = data.get("payload", {})

    match msg_type:
        case "material_add_request":
            await on_material_add_request(
                session,
                payload,
            )

        case "render_result":
            await on_render_result(
                session,
                payload,
            )

        case "material_search_request":
            await on_material_search_request(
                session,
                payload,
            )

        case _:
            await send_message(
                session.websocket,
                "error",
                {"message": f"Unknown type {msg_type}"},
            )


async def handle_client(
    websocket: ServerConnection,
):
    """Обрабатывает сообщения от одного подключенного Редактора."""
    session = ClientSession(websocket)

    client_id = id(websocket)

    connected_clients[client_id] = session

    lib_logger.info(f"Client connected: {client_id}")

    try:
        async for raw in websocket:
            lib_logger.info("RECV >", raw)

            try:
                data = json.loads(raw)

                await process_message(
                    session,
                    data,
                )

            except json.JSONDecodeError:
                await send_message(
                    websocket,
                    "error",
                    {"message": "Invalid JSON"},
                )

    finally:
        connected_clients.pop(
            client_id,
            None,
        )


async def main():
    # Запускаем сервер на localhost и порту 8765
    async with websockets.serve(handle_client, "localhost", 8765):
        lib_logger.info("WebSocket сервер запущен на ws://localhost:8765")

        await asyncio.Future()  # Бесконечно ожидаем


if __name__ == "__main__":
    asyncio.run(main())
