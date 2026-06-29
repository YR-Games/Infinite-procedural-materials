"""
core.py
Основные функции для работы с эмбеддингами и графом.
"""

from typing import List, Tuple

from scripts.compare import compare
from scripts.embedding_graph import (
    embedding_graph,
    material_graph,
    is_material_already_added
)


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


# Функции для API:
def add_nodes():
    embedding_graph.add_nodes(material_graph)


def add_render(str_image: str, material: str) -> bool:
    """
    Принимает base64 изображение, преобразовывает его в PIL
    и передавает в граф Материала на дальнейшёю обработку.
    """
    return material_graph.add_render(str_image, material)


def save():
    embedding_graph.save()


def find_similar_clusters(str_image: str) -> List[Tuple[str, float]]:
    return embedding_graph.find_similar_clusters(str_image)


def is_can_add_material(material: str)->bool:
    return is_material_already_added(material)