import asyncio
import json
import struct
from datetime import datetime


async def handle_client(reader, writer):
    print("Client connected")
    # Отправляем hello
    msg = {"type": "hello", "payload": {"time": str(datetime.now())}}
    json_bytes = json.dumps(msg).encode()
    packet = struct.pack("<I", len(json_bytes)) + json_bytes
    writer.write(packet)
    await writer.drain()

    # Ждем данные
    while True:
        try:
            header = await reader.read(4)
            if not header:
                break
            size = struct.unpack("<I", header)[0]
            data = await reader.read(size)
            if not data:
                break
            print("Received:", data)
        except:
            break
    writer.close()
    await writer.wait_closed()
    print("Client disconnected")


async def main():
    server = await asyncio.start_server(handle_client, "127.0.0.1", 8761)
    print("Server running")
    async with server:
        await server.serve_forever()


asyncio.run(main())
