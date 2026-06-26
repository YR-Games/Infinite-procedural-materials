# Протокол общения Godot ↔ Python Generator (TCP)

## Общая информация

- **Транспорт**: TCP
- **Хост**: 127.0.0.1
- **Порт**: 8765
- **Кодировка**: UTF-8 для JSON, бинарные данные для изображений

## Формат пакета

Все сообщения передаются в следующем формате:

```
┌──────────────┬────────────────────┬─────────────────────────┐
│ uint32 LE    │ JSON UTF-8 bytes   │ Бинарные данные (опц.)  │
├──────────────┼────────────────────┼─────────────────────────┤
│ json_length  │ metadata           │ payload (image, etc.)   │
└──────────────┴────────────────────┴─────────────────────────┘
```

- **json_length** (4 байта, little-endian): размер JSON-метаданных
- **metadata**: JSON-объект с полями `type` и `payload`
- **binary data** (опционально): дополнительные бинарные данные (изображения)

## Жизненный цикл соединения

1. **Установка соединения**: Godot подключается к серверу
2. **Handshake**: Сервер отправляет `hello` для подтверждения готовности
3. **Обмен сообщениями**: Клиент и сервер обмениваются сообщениями
4. **Закрытие**: Любая сторона может закрыть соединение

## Сообщения

### Handshake

#### Server → Client: `hello`

```json
{
  "type": "hello",
  "payload": {
    "message": "Connected to Generator TCP Server",
    "timestamp": "2026-06-26T15:09:19",
    "client_id": 1654330950720
  }
}
```

### Добавление материала

#### Client → Server: `material_add_request`

```json
{
  "type": "material_add_request",
  "payload": {
    "material": {
      // JSON-представление материала
    }
  }
}
```

#### Server → Client: `material_add_accepted`

```json
{
  "type": "material_add_accepted",
  "payload": {}
}
```

#### Server → Client: `material_add_rejected`

```json
{
  "type": "material_add_rejected",
  "payload": {
    "reason": "already_exists"
  }
}
```

### Генерация рендеров

#### Server → Client: `render_request`

```json
{
  "type": "render_request",
  "payload": {
    "parameters": {
      "seed": 1
    }
  }
}
```

#### Client → Server: `render_result`

**Бинарный формат:**

```
┌──────────────┬────────────────────┬─────────────────────────┐
│ uint32 LE    │ JSON UTF-8 bytes   │ JPEG bytes              │
├──────────────┼────────────────────┼─────────────────────────┤
│ json_length  │ metadata           │ image                   │
└──────────────┴────────────────────┴─────────────────────────┘
```

**metadata:**

```json
{
  "type": "render_result",
  "payload": {}
}
```

#### Server → Client: `render_accepted`

```json
{
  "type": "render_accepted",
  "payload": {
    "cluster_id": 1
  }
}
```

#### Server → Client: `render_rejected`

```json
{
  "type": "render_rejected",
  "payload": {}
}
```

### Завершение добавления материала

#### Server → Client: `material_add_completed`

```json
{
  "type": "material_add_completed",
  "payload": {
    "clusters_added": 5,
    "renders_checked": 5
  }
}
```

#### Server → Client: `material_add_stopped`

```json
{
  "type": "material_add_stopped",
  "payload": {
    "reason": "duplicate_limit"
  }
}
```

### Поиск материала

#### Client → Server: `material_search_request`

**Бинарный формат:**

```
┌──────────────┬────────────────────┬─────────────────────────┐
│ uint32 LE    │ JSON UTF-8 bytes   │ JPEG bytes              │
├──────────────┼────────────────────┼─────────────────────────┤
│ json_length  │ metadata           │ image                   │
└──────────────┴────────────────────┴─────────────────────────┘
```

**metadata:**

```json
{
  "type": "material_search_request",
  "payload": {}
}
```

#### Server → Client: `material_search_started`

```json
{
  "type": "material_search_started",
  "payload": {}
}
```

#### Server → Client: `search_progress`

```json
{
  "type": "search_progress",
  "payload": {
    "checked": 5,
    "total": 10
  }
}
```

#### Server → Client: `material_match_found`

```json
{
  "type": "material_match_found",
  "payload": {
    "similarity": 0.95,
    "material": {
      "id": "material_123"
    }
  }
}
```

#### Server → Client: `material_search_completed`

```json
{
  "type": "material_search_completed",
  "payload": {
    "matches_found": 3
  }
}
```

### Ошибки

#### Любая сторона: `error`

```json
{
  "type": "error",
  "payload": {
    "message": "Description of error"
  }
}
```

## Ограничения

- Максимальный размер JSON: 1 МБ
- Максимальный размер изображения: 10 МБ
- Рекомендуемый размер изображения: 512x512 пикселей
- Качество JPEG: 85% (оптимальный баланс размера/качества)

## Таймауты

- Ожидание handshake: 5 секунд
- Ожидание ответа на запрос: 10 секунд
- Интервал переподключения: 2 секунды
- Максимум попыток переподключения: 5

## Примеры

### Успешный поиск материала

```
1. Client → Server: material_search_request (с изображением)
2. Server → Client: material_search_started
3. Server → Client: search_progress (checked: 1, total: 10)
4. Server → Client: search_progress (checked: 2, total: 10)
5. Server → Client: material_match_found (similarity: 0.95)
6. Server → Client: search_progress (checked: 10, total: 10)
7. Server → Client: material_search_completed (matches_found: 3)
```

### Добавление материала

```
1. Client → Server: material_add_request
2. Server → Client: material_add_accepted
3. Server → Client: render_request (seed: 1)
4. Client → Server: render_result (с изображением)
5. Server → Client: render_accepted (cluster_id: 1)
6. Server → Client: render_request (seed: 2)
7. Client → Server: render_result (с изображением)
8. Server → Client: render_accepted (cluster_id: 2)
9. Server → Client: material_add_completed (clusters_added: 2, renders_checked: 2)
```

## Примечания

1. Все сообщения должны быть валидным JSON
2. Бинарные данные всегда идут после JSON-метаданных
3. Клиент должен дождаться `hello` от сервера перед отправкой запросов
4. При потере соединения клиент должен переподключиться автоматически