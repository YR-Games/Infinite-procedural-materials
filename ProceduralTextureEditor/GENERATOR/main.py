"""
main.py
Главный файл Генератора, управляющий вебсокетом и обеспечивающий программный интерфейс
для работы с графом ближайших соседей для добавления материалов и поиска подходящих.
"""

import json
import socket
from typing import Any

from core import add_nodes, add_render, find_similar_clusters, is_can_add_material
from scripts.logger import lib_logger


class CoreMock:
    """
    Заглушка для модуля core, имитирующая проверку уникальности рендеров.
    Потом должно считаться в графе Материала!
    """

    def __init__(self, threshold: int = 40):
        self.non_unique_count = 0
        self.threshold = threshold

    def add_render(self, image_data: str, material: str) -> bool:
        """
        Имитирует добавление рендера.
        Возвращает True, если рендер уникален, иначе False.
        Увеличивает счётчик неуникальных при False.
        """

        unique = add_render(image_data, material)
        if not unique:
            self.non_unique_count += 1
            lib_logger.info(f"Non-unique render, count={self.non_unique_count}")
        else:
            self.non_unique_count = 0
            lib_logger.info("Unique render")
        return unique


core = CoreMock()


def recv_message(sock: socket.socket) -> dict[str, Any] | None:
    """
    Читает из сокета одно сообщение (до символа '\n'),
    декодирует JSON и возвращает словарь.
    Возвращает None при ошибке или закрытии соединения.
    """
    try:
        data = b""
        lib_logger.info("Waiting for data...")
        while b"\n" not in data:
            # lib_logger.info("Waiting for chunk data...")
            chunk = sock.recv(4096)
            if not chunk:
                lib_logger.info("Connection closed by peer")
                return None
            data += chunk
            # lib_logger.debug(f"Received {len(chunk)} bytes")
        line, _ = data.split(b"\n", 1)
        lib_logger.info(f"Full message: {line[:100]}")
        return json.loads(line.decode("utf-8"))
    except Exception as e:
        lib_logger.error(f"Error receiving message: {e}")
        return None


def send_message(sock: socket.socket, msg: dict) -> None:
    """
    Отправляет словарь msg как JSON с завершающим '\n' через сокет.
    """
    try:
        sock.sendall((json.dumps(msg) + "\n").encode("utf-8"))
    except Exception as e:
        lib_logger.error(f"Error sending message: {e}")


def handle_add_material(sock: socket.socket, data: dict[str, Any], msg_id: str) -> None:
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
    send_message(sock, ack)

    if is_can_add_material(material):
        # Фиксированное количество рендеров, не более:
        max_renders = 300
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
            send_message(sock, req)
            lib_logger.info(f"Sent render_request {i}")

            # Ожидание ответа render_response
            resp = recv_message(sock)
            if resp is None:
                lib_logger.error("Connection closed while waiting for render_response")
                break
            if resp.get("type") == "render_response":
                data: dict[str, Any] = resp.get("data", {})
                material: str = data.get("material", "")
                image_data: str = data.get("image", "")
                unique = core.add_render(image_data, material)
                if not unique and core.non_unique_count > core.threshold:
                    stop_msg: dict[str, Any] = {
                        "type": "add_material_stop",
                        "data": {"reason": "too many non unique"},
                    }
                    send_message(sock, stop_msg)
                    lib_logger.warning(
                        "Stopping material addition due to too many non-unique renders"
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
        send_message(sock, finish_req)
        lib_logger.info("Sent final render_request with finished=True")

        # Ожидаем add_material_complete
        complete_resp = recv_message(sock)
        if complete_resp and complete_resp.get("type") == "add_material_complete":
            lib_logger.info(
                "Received add_material_complete, addition finished successfully."
            )
        else:
            lib_logger.error(
                "Expected add_material_complete but got something else or timeout"
            )
    else:
        lib_logger.warning("Material already added, SKIPPED!")


def handle_search_request(
    sock: socket.socket, data: dict[str, Any], msg_id: str
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
    send_message(sock, ack)

    # Имитация процесса поиска для красивого прогресс бара)
    prog_msg: dict[str, Any] = {
        "type": "search_progress",
        "id": msg_id,
        "data": {"progress": 0.9},
    }
    send_message(sock, prog_msg)

    materials = find_similar_clusters(image_data)
    for material in materials:
        # Отправляем найденные материалы
        result_msg: dict[str, Any] = {
            "type": "search_result",
            "id": msg_id,
            "data": {"material": material[0], "similarity": material[1]},
        }
        send_message(sock, result_msg)
        lib_logger.info(f"Sent search_result {material}")

        prog_msg: dict[str, Any] = {
            "type": "search_progress",
            "id": msg_id,
            "data": {"progress": 10},
        }
        send_message(sock, prog_msg)

    # Завершение поиска
    done_msg: dict[str, Any] = {"type": "search_done", "id": msg_id, "data": {}}
    send_message(sock, done_msg)
    lib_logger.info("Search finished")


def main() -> None:
    """
    Запускает TCP-сервер, принимает одно соединение от Редактора
    и обрабатывает входящие сообщения в бесконечном цикле.
    """
    host = "127.0.0.1"
    port = 12345

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((host, port))
    server.listen(1)
    lib_logger.info(f"Generator listening on {host}:{port}")

    conn, addr = server.accept()
    lib_logger.info(f"Connected by {addr}")
    lib_logger.info("Waiting for first message...")

    with conn:
        while True:
            try:
                msg = recv_message(conn)
                if msg is None:
                    lib_logger.info("Connection closed by client")
                    break

                msg_type = msg.get("type")
                msg_id = msg.get("id")
                data = msg.get("data", {})
                lib_logger.info(f"Received message type={msg_type}, id={msg_id}")

                if msg_type == "add_material":
                    handle_add_material(conn, data, msg_id)
                elif msg_type == "search_request":
                    handle_search_request(conn, data, msg_id)
                elif msg_type == "ping":
                    prog_msg: dict[str, Any] = {
                        "type": "ping",
                        "data": "0.0001 mc",
                    }
                    send_message(conn, prog_msg)
                else:
                    lib_logger.warning(f"Unhandled message type: {msg_type}")

            except Exception as e:
                lib_logger.error(f"Error: {e}")


if __name__ == "__main__":
    main()
