"""
main.py
Главный файл Генератора, управляющий вебсокетом и обеспечивающий программный интерфейс
для работы с графом ближайших соседей для добавления материалов и поиска подходящих.
"""

import asyncio
import json
from typing import Any

from core import add_nodes, add_render, find_similar_clusters, is_can_add_material
from scripts.logger import lib_logger


# ??? Перенести в core
class CoreMock:
    """
    Заглушка для модуля core, имитирующая проверку уникальности рендеров.
    Потом должно считаться в графе Материала!
    """

    def __init__(self, threshold: int = 500):
        self.non_unique_count = 0
        self.threshold = threshold

    def add_render(self, image_data: str, material: str, material_params: str) -> bool:
        """
        Имитирует добавление рендера.
        Возвращает True, если рендер уникален, иначе False.
        Увеличивает счётчик неуникальных при False.
        """

        unique = add_render(image_data, material, material_params)
        if not unique:
            self.non_unique_count += 1
            lib_logger.info(f"Non-unique render, count={self.non_unique_count}")
        else:
            self.non_unique_count = 0
            lib_logger.info("Unique render")
        return unique


core = CoreMock()


async def recv_message(
    reader: asyncio.StreamReader,
) -> dict[str, Any] | None:
    """
    Асинхронно читает из потока одно сообщение (до символа '\n'),
    декодирует JSON и возвращает словарь.
    Возвращает None при ошибке или закрытии соединения.
    """

    try:
        lib_logger.info("Waiting for data...")
        try:
            # readuntil возвращает данные ВКЛЮЧАЯ разделитель '\n'.
            # Если в буфере остались байты после '\n', они сохраняются
            # для следующего вызова.
            line = await reader.readuntil(b"\n")

        except asyncio.IncompleteReadError as e:
            # Соединение закрыто. e.partial — недочитанные байты.
            if e.partial:
                lib_logger.warning(
                    f"Connection closed mid-message, got {len(e.partial)} bytes"
                )
            else:
                lib_logger.info("Connection closed by peer")
            return None

        except asyncio.LimitOverrunError as e:
            # Строка превысила внутренний лимит StreamReader
            # (по умолчанию 64 KiB). Соединение нужно закрыть —
            # буфер остаётся "забитым".
            lib_logger.exception(
                f"Message exceeded reader limit ({e.consumed} bytes buffered)"
            )
            return None

        # Отбрасываем завершающий '\n'
        line = line[:-1]
        lib_logger.info(f"Full message: {line[:100]}")
        return json.loads(line.decode("utf-8"))

    except Exception as e:  # noqa: BLE001
        lib_logger.exception(f"Error receiving message: {e}")
        return None


async def send_message(
    writer: asyncio.StreamWriter,
    msg: dict[str, Any],
) -> None:
    """
    Асинхронно отправляет словарь msg как JSON с завершающим '\n'.
    """

    try:
        writer.write((json.dumps(msg) + "\n").encode("utf-8"))
        # drain() ждёт, пока данные уйдут в сокет (или пока буфер
        # не разгрузится настолько, чтобы принять новые байты).
        await writer.drain()
    except Exception as e:  # noqa: BLE001
        lib_logger.error(f"Error sending message: {e}")


async def handle_add_material(
    writer: asyncio.StreamWriter,
    reader: asyncio.StreamReader,
    data: dict[str, Any],
    msg_id: str,
) -> None:
    """
    Обрабатывает запрос на добавление материала.
    Отправляет ack, затем в цикле запрашивает рендеры через render_request,
    ожидает render_response, проверяет уникальность через core.add_render.
    При превышении порога неуникальных отправляет add_material_stop.
    После перебора всех параметров отправляет финальный render_request с finished=True
    и ожидает add_material_complete.
    """

    material: str = data.get("material", "")
    lib_logger.info(f"Handling add_material id={msg_id}, material={material[:100]}")

    # Подтверждение получения
    ack: dict[str, Any] = {
        "type": "add_material_ack",
        "id": msg_id,
        "data": {"status": "processing"},
    }
    await send_message(writer, ack)

    if is_can_add_material(material):
        unique_render_count: int = 0
        # Фиксированное количество рендеров, не более:
        max_renders = 1000
        for i in range(max_renders):
            # Запрос рендера
            req: dict[str, Any] = {
                "type": "render_request",
                "id": f"render_{i}",
                "data": {
                    "material": material,
                    "finished": False,
                },
            }
            await send_message(writer, req)
            lib_logger.info(f"Sent render_request {i}")

            # Ожидание ответа render_response
            resp: dict[str, Any] | None = await recv_message(reader)
            if resp is None:
                lib_logger.error("Connection closed while waiting for render_response")
                break
            if resp.get("type") == "render_response":
                resp_data: dict[str, Any] = resp.get("data", {})
                material: str = resp_data.get("material", "")
                material_params = resp_data.get("material_params", "")
                image_data: str = resp_data.get("image", "")
                unique = core.add_render(image_data, material, material_params)
                if unique:
                    unique_render_count += 1
                elif not unique and core.non_unique_count > core.threshold:
                    await _send_add_material_stop(writer, "too many non-unique")
                    lib_logger.warning(
                        f"Stopping material addition due to too many non-unique renders ({core.non_unique_count})"
                    )
                    break
            elif resp.get("type") == "renders_is_ower":
                lib_logger.info("Stopping material addition due to all renders sent")
                break
            else:
                lib_logger.warning(f"Unexpected response type: {resp.get('type')}")
                continue

        # Все параметры перебраны – отправляем финальный запрос и производим слияние графов.
        add_nodes()
        finish_req: dict[str, Any] = {
            "type": "render_request",
            "id": "finish",
            "data": {"finished": True, "material": material},
        }
        await send_message(writer, finish_req)
        lib_logger.info("Sent final render_request with finished=True")

        # Ожидаем add_material_complete
        complete_resp = await recv_message(reader)
        if complete_resp and complete_resp.get("type") == "add_material_complete":
            lib_logger.info(
                f"Received add_material_complete, addition finished successfully. {unique_render_count} unique renders have been added."
            )
        else:
            lib_logger.error(
                "Expected add_material_complete but got something else or timeout"
            )
    else:
        reason: str = "Material already added, SKIPPED!"
        await _send_add_material_stop(writer, reason)
        lib_logger.warning(reason)


async def _send_add_material_stop(writer: asyncio.StreamWriter, reason: str) -> None:
    stop_msg: dict[str, Any] = {
        "type": "add_material_stop",
        "data": {"reason": reason},
    }
    await send_message(writer, stop_msg)


async def handle_search_request(
    writer: asyncio.StreamWriter, data: dict[str, Any], msg_id: str
) -> None:
    """
    Обрабатывает запрос на поиск по эталонному изображению.
    Отправляет search_ack, затем периодически отправляет search_progress
    и search_result, в конце отправляет search_done.
    """

    image_data = data.get("image", "")
    lib_logger.info(
        f"Handling search_request id={msg_id}, image_data={image_data[:100]}"
    )

    ack: dict[str, Any] = {
        "type": "search_ack",
        "id": msg_id,
        "data": {"status": "processing"},
    }
    await send_message(writer, ack)

    # Имитация процесса поиска для красивого прогресс бара)
    prog_msg: dict[str, Any] = {
        "type": "search_progress",
        "id": msg_id,
        "data": {"progress": 0.9},
    }
    await send_message(writer, prog_msg)

    materials = find_similar_clusters(image_data)
    for material in materials:
        # Отправляем найденные материалы
        result_msg: dict[str, Any] = {
            "type": "search_result",
            "id": msg_id,
            "data": {"material": material[0], "similarity": material[1]},
        }
        await send_message(writer, result_msg)
        lib_logger.info(
            f"Sent search_result [material: {material[0][:100]} similarity: {material[1]}]"
        )

        prog_msg: dict[str, Any] = {
            "type": "search_progress",
            "id": msg_id,
            "data": {"progress": 10},
        }
        await send_message(writer, prog_msg)

    # Завершение поиска
    done_msg: dict[str, Any] = {"type": "search_done", "id": msg_id, "data": {}}
    await send_message(writer, done_msg)
    lib_logger.info("Search finished")


async def handle_client(
    reader: asyncio.StreamReader, writer: asyncio.StreamWriter
) -> None:
    """
    Функция-обработчик соединения с одним клиентом.
    """

    addr = writer.get_extra_info("peername")
    lib_logger.info(f"Connected by {addr}. Waiting for first message...")
    try:
        while True:
            # Предполагается, что recv_message_async реализован через reader
            msg: dict[str, Any] | None = await recv_message(reader)
            if msg is None:
                break

            msg_type = msg.get("type")
            msg_id: str = msg.get("id")  # type: ignore
            data: dict[str, Any] = msg.get("data", {})
            lib_logger.info(f"Received message type={msg_type}, id={msg_id}")

            if msg_type == "add_material":
                await handle_add_material(writer, reader, data, msg_id)
            elif msg_type == "search_request":
                await handle_search_request(writer, data, msg_id)
            elif msg_type == "ping":
                await send_message(writer, {"type": "ping", "data": "0.0001 mc"})
            else:
                lib_logger.warning(f"Unhandled message type: {msg_type}")

    except Exception as e:  # noqa: BLE001
        lib_logger.exception(f"Error with {addr}: {e}")
    finally:
        writer.close()
        await writer.wait_closed()
        lib_logger.info(f"Connection closed by {addr}")


async def main() -> None:
    """
    Запускает TCP-сервер, принимает соединения от Редакторов
    и обрабатывает входящие сообщения.
    """

    host, port = "127.0.0.1", 12345
    # limit — максимальный размер буфера StreamReader (в байтах).
    # Поднимаем до 10 МБ, т.к. сообщения могут быть больше 64 KiB.
    server = await asyncio.start_server(
        handle_client, host, port, limit=1000 * 1024 * 1024
    )
    lib_logger.info(f"Generator listening on {host}:{port}")
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
