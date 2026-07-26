"""
scripts/compare.py
Улучшенная библиотека для сравнения изображений
"""

import os
from collections import defaultdict
from functools import lru_cache

import cv2
import matplotlib.pyplot as plt
import numpy as np
import torch
from PIL import Image
from sklearn.manifold import MDS

from .logger import lib_logger
from .models_manager import get_embedding, load_and_transform_image, threshold
from .utils import calculate_similarity, tensor_to_pil


@lru_cache(maxsize=1000)
def _get_norm_embedding(image: str) -> torch.Tensor:
    """Возвращает нормализованный эмбеддинг по пути к изображению."""
    embedding: torch.Tensor = get_embedding(image, False).squeeze()
    return embedding / torch.norm(embedding, p=2)  # Нормализуем


def compare(image_path1: str, image_path2: str) -> dict[str, float]:
    result: dict[str, float] = {}
    try:
        result["DINOv2"] = torch.dot(
            _get_norm_embedding(image_path1), _get_norm_embedding(image_path2)
        ).item()
    except Exception as e:
        lib_logger.error(
            f"Error DINOv2 comparing images {image_path1} and {image_path2}: {e}"
        )
    try:
        result["SSIM (> 95: 🔥; < 80: 👎)"] = calculate_ssim(image_path1, image_path2)
    except Exception as e:
        lib_logger.error(
            f"Error SSIM comparing images {image_path1} and {image_path2}: {e}"
        )
    try:
        result["PSNR (> 40: 🔥; < 20: 👎)"] = calculate_psnr(image_path1, image_path2)
    except Exception as e:
        lib_logger.error(
            f"Error PSNR comparing images {image_path1} and {image_path2}: {e}"
        )
    return result


def calculate_psnr(image1: str, image2: str) -> float:
    # Изображения должны быть одинакового размера и типа
    img1 = cv2.imread(image1)
    img2 = cv2.imread(image2)
    return cv2.PSNR(img1, img2)


def calculate_ssim(image1: str, image2: str) -> float:
    img1 = cv2.imread(image1)
    img2 = cv2.imread(image2)
    # Константы для стабильности формулы SSIM
    C1 = (0.01 * 255) ** 2
    C2 = (0.03 * 255) ** 2

    # Преобразование в float32 для точности вычислений
    img1 = img1.astype(np.float64)
    img2 = img2.astype(np.float64)

    # Вычисление средних значений (ядро Гаусса 11x11, sigma=1.5)
    mu1 = cv2.GaussianBlur(img1, (11, 11), 1.5)
    mu2 = cv2.GaussianBlur(img2, (11, 11), 1.5)

    mu1_sq = mu1**2
    mu2_sq = mu2**2
    mu1_mu2 = mu1 * mu2

    # Вычисление дисперсий и ковариации
    sigma1_sq = cv2.GaussianBlur(img1**2, (11, 11), 1.5) - mu1_sq
    sigma2_sq = cv2.GaussianBlur(img2**2, (11, 11), 1.5) - mu2_sq
    sigma12 = cv2.GaussianBlur(img1 * img2, (11, 11), 1.5) - mu1_mu2

    # Формула SSIM
    ssim_map = ((2 * mu1_mu2 + C1) * (2 * sigma12 + C2)) / (
        (mu1_sq + mu2_sq + C1) * (sigma1_sq + sigma2_sq + C2)
    )

    return round(ssim_map.mean(), 5)


class TextureComparator:
    """Класс для сравнения текстур с кэшированием и настройками"""

    def __init__(self):
        pass  # self.model = get_embedding_model()

    def compare(self, image1_path: str, image2_path: str) -> tuple[float, float]:
        """
        Сравнивает два изображения и возвращает степень сходства (0-1)

        Args:
            image1_path: путь к первому изображению
            image2_path: путь ко второму изображению

        Returns:
            float: расстояние между изображениями (0 - идентичны, 1 - совсем не похожи)
            float: степень сходства от 1 (совсем не похожи) до 0 (идентичны)
        """
        try:
            output1 = get_embedding(image1_path)
            output2 = get_embedding(image2_path)

            # Нормализуем расстояние.
            dist1, sim1 = calculate_similarity(output1, output2)
            return dist1, sim1

        except Exception as e:
            lib_logger.error(
                f"Error comparing images {image1_path} and {image2_path}: {e}"
            )
            raise


# Глобальный инстанс для обратной совместимости
_comparator = None


def get_comparator() -> TextureComparator:
    """Получение инстанса компаратора (singleton)"""
    global _comparator
    if _comparator is None:
        _comparator = TextureComparator()
    return _comparator


'''
def compare(image1_path: str, image2_path: str) -> float:
    """
    Функция сравнения двух изображений.

    Args:
        image1_path: путь к первому изображению
        image2_path: путь ко второму изображению

    Returns:
        float: степень сходства от 0 до 1
    """
    comparator = get_comparator()
    similarity, dist = comparator.compare(image1_path, image2_path)
    print("sim: ", similarity, ", dist: ", dist)

    return similarity
'''


def str_compare(image1_path: str, image2_path: str) -> str:
    """
    Функция сравнения двух изображений.

    Args:
        image1_path: путь к первому изображению
        image2_path: путь ко второму изображению

    Returns:
        похожи или нет
        расстояние между изоюражениями от 0 (идентичны) до <много> (совсем не похожи)
        порог уверенности в схожести изображений
    """
    comparator = get_comparator()
    _, distance = comparator.compare(image1_path, image2_path)
    return f"Изображения {'похожи' if distance < threshold else 'не похожи'}, расстояние: {distance:.3f}, порог уверенности: {threshold}"


def cluster_images(image_paths: list[str]) -> list[list[str]]:
    from tqdm import tqdm

    """
    Функция кластеризации изображений по текстуре.

    Args:
        image_paths: список путей к изображениям

    Returns:
        List[List[str]]:
            Структура - кластеры по текстуре (список списков путей),
            Каждый кластер - группа изображений, где расстояния между эмбеддингами <= threshold.
            Каждое изображение попадает хотя бы в один кластер (одиночные - отдельные кластеры).
    """
    # Получаем эмбеддинги для всех изображений
    embeddings: list[torch.Tensor] = []
    for _idx, path in enumerate(tqdm(image_paths, desc="Генерация эмбеддингов")):
        emb = get_embedding(path)
        embeddings.append(emb)

    # Функция для кластеризации одного типа эмбеддингов
    def cluster_by_type(emb_list: list[torch.Tensor]) -> list[list[str]]:
        n = len(image_paths)
        # Строим граф: соединяем, если distance <= threshold
        graph = defaultdict(list)
        total_pairs = n * (n - 1) // 2  # количество уникальных пар
        with tqdm(total=total_pairs, desc="Сравнение изображений") as pbar:
            for i in range(n):
                for j in range(i + 1, n):
                    _, dist = calculate_similarity(emb_list[i], emb_list[j])
                    print(
                        f"Сравнение изображений: '{i}', '{j}', результат: {dist}, порог: {threshold}"
                    )
                    if dist <= threshold:
                        graph[i].append(j)
                        graph[j].append(i)
                    pbar.update(1)

        # Находим connected components (кластеры)
        visited = [False] * n
        clusters: list[list[str]] = []
        for i in range(n):
            if not visited[i]:
                # BFS для компоненты
                cluster = []
                queue = [i]
                visited[i] = True
                while queue:
                    node = queue.pop(0)
                    cluster.append(image_paths[node])
                    for neighbor in graph[node]:
                        if not visited[neighbor]:
                            visited[neighbor] = True
                            queue.append(neighbor)
                clusters.append(cluster)
        print(f"Всего рёбер: {sum(len(neigh) for neigh in graph.values()) // 2}")  # type: ignore
        return clusters

    # Кластеризация по текстуре
    clusters = cluster_by_type(embeddings)

    return clusters


# ??? Полностью переделать на нормальный граф!
def visualize_clusters(
    clusters: list[list[str]],
    output_dir: str = "data/input/visualizations",
):
    from tqdm import tqdm

    """
    Визуализирует кластеры по микротекстуре и макротекстуре.
    
    Для каждого кластера создает изображение с маленькими версиями исходных изображений, расположенными рядом.
    Сохраняет эти изображения в output_dir.
    
    Также создает общее изображение для каждого типа (микро и макро), отображающее взаимное расположение кластеров на плоскости,
    где расстояния между точками отражают расстояния между центроидами кластеров.
    
    Args:
        clusters: кластеры по микротекстуре (список списков путей)
        output_dir: директория для сохранения изображений
    """
    os.makedirs(output_dir, exist_ok=True)

    def visualize_single_clusters(clusters: list[list[str]]):
        """
        Визуализирует кластеры одного типа.
        """
        cluster_files = []
        centroids = []

        for idx, cluster in enumerate(tqdm(clusters, desc="Обработка кластеров")):
            if not cluster:
                continue

            # Получаем эмбеддинги для кластера
            embs = []
            images = []
            for path in cluster:
                emb = get_embedding(path)
                embs.append(emb)
                images.append(tensor_to_pil(load_and_transform_image(path, 100, False)))

            # Создаем изображение кластера: располагаем маленькие изображения в сетке
            cols = int(np.ceil(np.sqrt(len(images))))
            rows = int(np.ceil(len(images) / cols))
            cluster_img = Image.new("RGB", (cols * 100, rows * 100), (255, 255, 255))

            for i, img in enumerate(images):
                x = (i % cols) * 100
                y = (i // cols) * 100
                cluster_img.paste(img, (x, y))

            cluster_file = f"cluster_{idx}.png"
            cluster_img.save(os.path.join(output_dir, cluster_file))
            cluster_files.append(cluster_file)

            # Центроид кластера
            centroids.append(torch.stack(embs).mean(dim=0))

        # Расстояния между центроидами
        n_clusters = len(centroids)
        distances = np.zeros((n_clusters, n_clusters))
        for i in range(n_clusters):
            for j in range(i + 1, n_clusters):
                _, dist = calculate_similarity(centroids[i], centroids[j])
                distances[i, j] = dist
                distances[j, i] = dist

        # MDS для 2D размещения
        if n_clusters > 1:
            mds = MDS(n_components=2, dissimilarity="precomputed", random_state=42)
            coords = mds.fit_transform(distances)
        else:
            coords = np.array([[0, 0]])

        # Визуализация общего расположения
        plt.figure(figsize=(10, 10))
        for i, (x, y) in enumerate(coords):
            plt.scatter(x, y, s=100)
            plt.text(x, y, cluster_files[i], fontsize=12, ha="center", va="center")
        plt.title("Расположение кластеров по текстуре")
        plt.axis("off")
        plt.savefig(os.path.join(output_dir, "overview.png"))
        plt.close()

    # Визуализируем
    visualize_single_clusters(clusters)
