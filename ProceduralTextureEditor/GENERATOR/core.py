"""
core.py
Основные функции для работы с эмбеддингами и графом.
"""

from scripts.compare import compare
from scripts.embedding_graph import (
    embedding_graph,
    is_material_already_added,
    material_graph,
)


def compare_images(
    image_paths1: list[str], image_paths2: list[str]
) -> list[dict[str, float]]:
    """
    Сравнивает пары изображений, где первой берётся из списка 1,
    второе из списка 2 и возвращает степень сходства по 3 метрикам.

    Args:
        image_path1: Пути к первым изображениям
        image_path2: Пути ко вторым изображениям

    Returns:
        Список словарей, где ключи - строковые названия методов, значений - степени сходства от 0.0 до 1.0.
    """
    count: int = min(image_paths1.__len__(), image_paths2.__len__())
    result: list[dict[str, float]] = []
    for i in range(count):
        result.append(compare(image_paths1[i], image_paths2[i]))
    return result


# Функции для API:
def add_nodes():
    embedding_graph.add_nodes(material_graph)


def add_render(str_image: str, material: str, material_params: str) -> bool:
    """
    Принимает base64 изображение, преобразовывает его в PIL
    и передавает в граф Материала на дальнейшёю обработку.
    """
    return material_graph.add_render(str_image, material, material_params)


def save():
    embedding_graph.save()


def find_similar_clusters(str_image: str) -> list[tuple[str, float]]:
    return embedding_graph.find_similar_clusters(str_image)


def is_can_add_material(material: str) -> bool:
    return is_material_already_added(material)
