"""
core.py
Основные функции для работы с эмбеддингами и графом.
"""

from typing import Any, List, Tuple

import numpy as np

from scripts.compare import compare
from scripts.embedding_graph import (
    embedding_graph,
    material_graph,
)

from PIL import Image


def compare_images(image_path1: str, image_path2: str) -> float:
    """??? УСТАРЕЛО: Должен работать с изображениями, а не путями!
    Сравнивает два изображения и возвращает степень сходства.

    Args:
        image_path1: Путь к первому изображению
        image_path2: Путь ко второму изображению

    Returns:
        float: Степень сходства от 0.0 до 1.0
    """
    return compare(image_path1, image_path2)


def add_to_embedding_graph(image_path: str) -> int:
    """??? УСТАРЕЛО: при вызове должен передавать в embedding_graph.add_nods(MaterialGraph) (а может и вообще без параметров, так как add_nods может использовать global material_graph)
    Добавляет изображение в существующий граф эмбеддингов.

    Args:
        image_path: Путь к изображению

    Returns:
        int: ID кластера, к которому отнесено изображение
    """
    return embedding_graph.add_image(image_path)


def add_to_material_graph(
    material_id: str,
    embedding: np.ndarray,
    image_path: str,
    parameters: dict[str, Any] = {},
):
    """Обрабатывает создание и добавление всех рендеров материала в его граф."""
    pass


def find_similar_clusters(image_path: str, k: int = 5) -> List[Tuple[int, float]]:
    """??? УСТАРЕЛО: должен принимать изображение, а не путь
    Находит k наиболее похожих кластеров для изображения.

    Args:
        image_path: Путь к изображению
        k: Количество возвращаемых кластеров

    Returns:
        List[Tuple[int, float]]: Список (ID кластера, степень сходства)
    """
    return embedding_graph.find_similar_clusters(image_path, k)


def visualize_clusters_for(is_emb_graph: bool = True):
    """Строит граф для изображений из переданной папки и визуализирует кластеры."""
    if is_emb_graph:
        embedding_graph.visualize_clusters()
    else:
        material_graph.visualize_clusters()


# Функции для API:
def init_material_adding(material: dict):
    """
    Запускает процесс добавление Материала:
        * Инициализирует граф материала;
        * Запускает цикл пополнения графа материала.
    """
    # import sqlite3
    pass  # ??? Принимает на вход материал, отправляет запросы на получение предпросмотра, определяет попадает ли он в
    # в новый кластер (относительно материала) или в уже существующий.
    # Если в новый - добавляем в граф, если в старый - пропускаем и делаем запрос на новый предпросмотр.
    # Останавливается тогда, когда приходит сообщение о том, что параметры для перебора закончились или 10
    # раз подряд приходят не в новые кластеры.


def add_render(image: Image.Image)->bool:
    """Должен принимать PIL изображение и передавать его в граф Материала на дальнейшёю обработку"""
    return material_graph.add_render(image)
