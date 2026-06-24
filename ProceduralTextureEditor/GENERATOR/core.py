"""
core.py
Основные функции для работы с эмбеддингами и графом.
"""

import os
from typing import Any, List, Tuple

import numpy as np

from scripts.compare import compare
from scripts.embedding_graph import EmbeddingGraph, embedding_graph, set_claster_threshhold, get_cluster_threshold


def get_next_params_set(params: dict)->dict:
    """Циклически увеличивает значения параметров."""
    for p in params:
        match params[p].get("type"):
            case "int":
                params[p] = get_next_int(params[p].get("value"), params[p].get("min"), params[p].get("max"), params[p].get("step"))
            case "float":
                params[p] = get_next_float(params[p].get("value"), params[p].get("min"), params[p].get("max"), params[p].get("step"))
    return params


def compare_images(image_path1: str, image_path2: str) -> float:
    """
    Сравнивает два изображения и возвращает степень сходства.

    Args:
        image_path1: Путь к первому изображению
        image_path2: Путь ко второму изображению

    Returns:
        float: Степень сходства от 0.0 до 1.0
    """
    return compare(image_path1, image_path2)
    # return TextureComparator.compare(image_path1, image_path2)


def build_embedding_graph(image_paths: List[str]) -> EmbeddingGraph:
    """
    Строит граф эмбеддингов для списка изображений.

    Args:
        image_paths: Список путей к изображениям

    Returns:
        EmbeddingGraph: Построенный граф эмбеддингов
    """
    # embedding_model = models_manager.get_embedding_model()
    # embedding_graph.use_model(embedding_model)
    embedding_graph.build_from_images(image_paths)
    return embedding_graph


def add_to_embedding_graph(image_path: str) -> int:
    """
    Добавляет изображение в существующий граф эмбеддингов.

    Args:
        image_path: Путь к изображению

    Returns:
        int: ID кластера, к которому отнесено изображение
    """
    return embedding_graph.add_image(image_path)

def add_to_material_graph(material_id: str,
        embedding: np.ndarray,
        image_path: str,
        parameters: dict[str, Any] = {},):
    """Обрабатывает создание и добавление всех рендеров материала в его граф."""
    pass


def find_similar_clusters(image_path: str, k: int = 5) -> List[Tuple[int, float]]:
    """
    Находит k наиболее похожих кластеров для изображения.

    Args:
        image_path: Путь к изображению
        k: Количество возвращаемых кластеров

    Returns:
        List[Tuple[int, float]]: Список (ID кластера, степень сходства)
    """
    return embedding_graph.find_similar_clusters(image_path, k)


def visualize_clusters_for(test_dir: str = "data/input/test_bib/"):
    """Строит граф для изображений из переданной папки и визуализирует кластеры."""
    paths: list[str] = []
    for filename in os.listdir(test_dir):
        if filename.lower().endswith((".png", ".jpg", ".jpeg")):
            filepath: str = os.path.join(test_dir, filename)
            paths.append(filepath)

    embedding_graph.build_from_images(paths)

    embedding_graph.visualize_clusters()


def update_claster_threshhold(_claster_threshhold: float):
    set_claster_threshhold(_claster_threshhold)


def get_claster_threshhold() -> float:
    return get_cluster_threshold()


# Функции для API:
def add_material():
    # import sqlite3
    pass  # ??? Принимает на вход материал, отправляет запросы на получение предпросмотра, определяет попадает ли он в
    # в новый кластер (относительно материала) или в старый.
    # Если в новый - добавляем в граф, если в старый - пропускаем и делаем запрос на новый предпросмотр.
    # Останавливается тогда, когда заканчиваются варианты для перебора или три раза подряд приходят не в разные кластеры.
