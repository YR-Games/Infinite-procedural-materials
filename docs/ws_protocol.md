# Generator ↔ Editor WebSocket Protocol

## Общий формат сообщения

Все сообщения передаются в формате JSON.

```json
{
  "type": "message_type",
  "payload": {}
}
```

---

# Добавление материала

## Editor → Generator

Запрос на добавление нового материала.

```json
{
  "type": "material_add_request",
  "payload": {
    "material": {}
  }
}
```

После отправки Editor ожидает подтверждение.

Если в течение 10 секунд подтверждение не получено — запрос отправляется повторно.

---

## Generator → Editor

Подтверждение получения материала и начала обработки.

```json
{
  "type": "material_add_accepted",
  "payload": {}
}
```

---

## Generator → Editor

Материал не может быть обработан.

```json
{
  "type": "material_add_rejected",
  "payload": {
    "reason": "already_exists"
  }
}
```

---

# Генерация рендеров

## Generator → Editor

Запрос на генерацию следующего рендера.

```json
{
  "type": "render_request",
  "payload": {
    "parameters": {}
  }
}
```

Поле `parameters` содержит значения параметров материала, которые необходимо применить перед рендерингом.

---

## Editor → Generator

Результат генерации рендера.

```json
{
  "type": "render_result"
}
```
BINARY
<jpg bytes>

---

## Generator → Editor

Рендер добавлен в новый кластер.

```json
{
  "type": "render_accepted",
  "payload": {}
}
```

---

## Generator → Editor

Рендер относится к уже существующему кластеру.

```json
{
  "type": "render_rejected",
  "payload": {}
}
```

---

# Завершение пополнения графа материала

## Editor → Generator

Сообщение о том, что пространство параметров полностью перебрано.

```json
{
  "type": "parameter_space_exhausted",
  "payload": {}
}
```

---

## Generator → Editor

Материал успешно добавлен.

```json
{
  "type": "material_add_completed",
  "payload": {
    "clusters_added": 24,
    "renders_checked": 631
  }
}
```

---

## Generator → Editor

Добавление материала остановлено из-за большого числа повторов.

```json
{
  "type": "material_add_stopped",
  "payload": {
    "reason": "duplicate_limit"
  }
}
```

Причина остановки:

* 10 подряд рендеров попали в уже существующие кластеры.

---

# Поиск материала по изображению

## Editor → Generator

Запрос поиска материала.

```json
{
  "type": "material_search_request",
}
```
BINARY
<jpg bytes>

После отправки Editor ожидает подтверждение.

Если в течение 10 секунд подтверждение не получено — запрос отправляется повторно.

---

## Generator → Editor

Подтверждение начала поиска.

```json
{
  "type": "material_search_started",
  "payload": {}
}
```

---

# Прогресс поиска

## Generator → Editor

Информация о ходе поиска.

```json
{
  "type": "search_progress",
  "payload": {
    "checked": 370,
    "total": 1000
  }
}
```

Где:

* `checked` — количество уже проверенных материалов;
* `total` — общее количество материалов.

---

# Найденный материал

## Generator → Editor

Сообщение отправляется каждый раз при обнаружении подходящего материала.

```json
{
  "type": "material_match_found",
  "payload": {
    "similarity": 0.92,
    "material": {}
  }
}
```

Где:

* `similarity` — степень сходства от 0.0 до 1.0;
* `material` — JSON-представление материала.

Editor должен добавлять материал в список результатов и пересортировывать список по мере поступления новых совпадений.

---

# Завершение поиска

## Generator → Editor

Поиск завершён.

```json
{
  "type": "material_search_completed",
  "payload": {
    "matches_found": 47
  }
}
```

---

# Ошибки

## Generator → Editor

```json
{
  "type": "error",
  "payload": {
    "message": "Description of error"
  }
}
```

---

## Editor → Generator

```json
{
  "type": "error",
  "payload": {
    "message": "Description of error"
  }
}
```

---

# Ограничения протокола

Для одного WebSocket подключения одновременно допускается:

* не более одного добавляемого материала;
* не более одного активного поиска;
* не более одного ожидающего рендера.

Состояние обработки хранится на стороне Generator внутри сессии клиента.
