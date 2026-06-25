"""
scripts/embedding_graph.py
Структура данных для эффективного хранения и поиска кластеров эмбеддингов.
"""

import pickle
from dataclasses import dataclass
from functools import lru_cache
from typing import Any, Dict, List, Tuple

from PIL import Image
import faiss
import numpy as np
from sklearn.cluster import DBSCAN
from tqdm import tqdm

from .logger import lib_logger
from .models_manager import get_embedding, load_and_transform_image

# Глобальные параметры.
cluster_threshold: float = 0.75


def set_claster_threshhold(_claster_threshhold: float):
    """Внешний интерфейс, устанавливающий минимальное расстояние между похожими векторами."""
    global cluster_threshold
    cluster_threshold = _claster_threshhold


def get_cluster_threshold() -> float:
    """Внешний интерфейс, возвращающий текущее минимальное расстояние между похожими векторами."""
    global cluster_threshold
    return cluster_threshold


# Вспомогательные классы.
@dataclass
class RenderNode:
    """Узел графа, связывающий Материал с эмбеддингом."""

    material_id: str
    embedding: np.ndarray
    rener_cache: Image
    parameters: dict[str, Any]

    def __init__(
        self,
        material_id: str,
        embedding: np.ndarray,
        rener_cache: Image,
        parameters: Dict[str, Any] = {},
    ) -> None:
        self.material_id = material_id
        self.embedding = embedding
        self.rener_cache = rener_cache
        self.parameters = parameters


# ??? доработать структуру данных
@dataclass
class ClusterNode:
    """Узел кластера в графе."""

    id: int
    centroid: np.ndarray
    nodes: List[RenderNode]
    size: int


class AbstractGraph:
    def __init__(self):
        self.clusters: Dict[int, ClusterNode] = {}
        self.next_cluster_id = 0

        # Используем FAISS для эффективного поиска ближайших соседей
        self.index = None
        self.embeddings: list[np.ndarray] = []
        self.cluster_labels = []

    @lru_cache(maxsize=500)
    def _get_norm_embedding(self, image_path: str) -> np.ndarray:
        """Возвращает нормализованный эмбеддинг по пути к изображению."""
        embedding = get_embedding(image_path).numpy().squeeze()
        return embedding / np.linalg.norm(embedding)  # Нормализуем

    def _get_centroid(self, cluster_id: int) -> np.ndarray:
        """По эмбеддингам кластера строит и возвращает его центроид."""
        centroid = np.mean(self.embeddings[cluster_id], axis=0)
        return centroid / np.linalg.norm(centroid)  # Нормализуем

    def _build_index(self, labels):
        """??? Не доделано и не интегрировано!"""
        # Строим индекс FAISS для быстрого поиска
        self.index = faiss.IndexFlatIP(
            self.embeddings.shape[1]
        )  # Inner product для косинусного сходства
        self.index.add(self.embeddings)
        self.cluster_labels = labels


# Основные графы:
class MaterialGraph(AbstractGraph):
    """
    Граф, каждый элемент которого - RenderNode,
    эмбеддинги которых удалены друг от друга
    на расстояние не менее cluster_threshold.

    Для расширяимости и отладки стуктура нод такая:
    ClusterNode <-содержит единственный- RenderNode.
    """

    def __init__(self):
        super().__init__()
        self.query: np.ndarray

    def _clear(self):
        """Очищает граф."""
        self.clusters: Dict[int, ClusterNode] = {}
        self.next_cluster_id = 0
        self.index = None
        self.embeddings: list[np.ndarray] = []
        self.cluster_labels: np.ndarray = []

    def add_render(self, image) -> bool:
        """??? УСТАРЕЛ и не доделан!
        Добавляет рендер в граф Материала и возвращает истину, если он добавлен в новый кластер,
        ложь - пропущен, так как слишком похож на уже добавленные.

        Если расстояние до соседей меньше cluster_threshold, то такое изображение пропускается,
        если больше, то оно добавляется в граф Материала.
        """
        global cluster_threshold
        embedding = self._get_norm_embedding(image_path)

        if embedding in self.embeddings:
            # Ищем ближайшие кластеры
            best_cluster_id = -1
            best_similarity = -1

            for cluster_id, cluster in self.clusters.items():
                similarity = np.dot(embedding, cluster.centroid)
                if similarity > best_similarity and similarity > cluster_threshold:
                    best_similarity = similarity
                    best_cluster_id = cluster_id

            if best_cluster_id != -1:
                # Добавляем в существующий кластер
                self.clusters[best_cluster_id].image_paths.append(image_path)
                self.clusters[best_cluster_id].size += 1
                # Обновляем центроид
                self.clusters[best_cluster_id].centroid = self._get_centroid(
                    best_cluster_id
                )
                return best_cluster_id
            else:
                # Создаем новый кластер
                new_cluster = ClusterNode(
                    id=self.next_cluster_id,
                    centroid=embedding,
                    image_paths=[image_path],
                    size=1,
                )
                self.clusters[self.next_cluster_id] = new_cluster
                self.next_cluster_id += 1
                return True
        else:
            return False

    # Отладочные интерфейсы:
    def build_from_images(self, image_paths: List[str]):
        """
        Строит граф из списка изображений. !Сбрасывает старый граф!
        Отладочный метод для проверки работоспособности.
        """
        # Сброс состояния графа.
        lib_logger.info("Удаление всех элементов старого графа материала... 🗑️")
        self._clear()

        lib_logger.info(f"Извлечение эмбеддингов {len(image_paths)}... ⚙️")
        embeddings: list[np.ndarray] = []
        valid_paths: list[str] = []

        for path in tqdm(image_paths, desc="Извлечение эмбеддингов"):
            try:
                embedding = self._get_norm_embedding(path)
                embeddings.append(embedding)
                valid_paths.append(path)
            except Exception as e:
                lib_logger.error(f"Ошибка обработки {path}: {e}")

        self.embeddings = np.array(embeddings)

        lib_logger.info("Кластеризация... ⚙️")
        self._build_clusters(valid_paths)

    def _build_clusters(self, image_paths: list[str]):
        """
        Создаёт кластеры с использованием DBSCAN из списка путей к рендерам материала.
        """
        global cluster_threshold

        lib_logger.info("Объединение графов... ⚙️")

        # Нормализуем эмбеддинги для косинусного расстояния
        faiss.normalize_L2(self.embeddings)

        # Используем DBSCAN для кластеризации
        clustering = DBSCAN(eps=1.0 - cluster_threshold, min_samples=1, metric="cosine")
        labels = clustering.fit_predict(self.embeddings)
        lib_logger.debug(
            f"Обрабатывается {len(labels)} lables, уникальных {len(set(labels))}\n",
            f"Состав labels: {labels}",
        )

        # Создаем кластеры
        for cluster_id in set(labels):
            if cluster_id == -1:  # Выбросы
                mask = labels == cluster_id
                continue

            mask = labels == cluster_id
            render = RenderNode(str(mask), self.embeddings[mask], image_paths[mask])

            cluster_node = ClusterNode(
                id=self.next_cluster_id,
                centroid=self._get_centroid(mask),
                nodes=[render],
                size=len(nodes),
            )

            lib_logger.debug(
                f"Число уникальных путей в кластере №{cluster_id}: {len(list(set(cluster_node.image_paths)))}, чило элементов кластера: {len(cluster_node.image_paths)}",
            )

            self.clusters[self.next_cluster_id] = cluster_node
            self.next_cluster_id += 1

        self._build_index(labels)

        lib_logger.info(f"Создано {len(self.clusters)} кластеров🗜️")


class EmbeddingGraph(AbstractGraph):
    """
    Граф для хранения и поиска кластеров эмбеддингов.
    Создаётся путём добавления MaterialGraph.
    """

    def __init__(self):
        super().__init__()
        self.preview_image_size: int = 256

    def add_nods(self, material_graph: MaterialGraph):
        """
        Дополняет/создаёт кластеры с использованием DBSCAN из графа рендеров материала.
        ??? Код устарел, не дописан!
        """
        global cluster_threshold

        lib_logger.info("Объединение графов... ⚙️")

        # Нормализуем эмбеддинги для косинусного расстояния
        faiss.normalize_L2(self.embeddings)

        # Используем DBSCAN для кластеризации
        clustering = DBSCAN(eps=1.0 - cluster_threshold, min_samples=1, metric="cosine")
        labels = clustering.fit_predict(self.embeddings)
        lib_logger.debug(
            f"Обрабатывается {len(labels)} lables, уникальных {len(set(labels))}\n",
            f"Состав labels: {labels}",
        )

        # Создаем кластеры
        for cluster_id in set(labels):
            if cluster_id == -1:  # Выбросы
                mask = labels == cluster_id
                continue

            mask = labels == cluster_id
            nodes = [
                RenderNode(str(i), self.embeddings[i], image_paths[i])
                for i in range(len(image_paths))
                if mask[i]
            ]

            cluster_node = ClusterNode(
                id=self.next_cluster_id,
                centroid=self._get_centroid(mask),
                nodes=nodes,
                size=len(nodes),
            )

            lib_logger.debug(
                f"Число уникальных путей в кластере №{cluster_id}: {len(list(set(cluster_node.image_paths)))}, чило элементов кластера: {len(cluster_node.image_paths)}",
            )

            self.clusters[self.next_cluster_id] = cluster_node
            self.next_cluster_id += 1

        self._build_index(labels)

        lib_logger.info(f"Создано {len(self.clusters)} кластеров🗜️")

    def find_similar_clusters(
        self, image_path: str, k: int = 5
    ) -> List[Tuple[int, float]]:
        """Находит k наиболее похожих кластеров для изображения."""
        embedding = self._get_norm_embedding(image_path)

        similarities = []
        for cluster_id, cluster in self.clusters.items():
            similarity = np.dot(embedding, cluster.centroid)
            similarities.append((cluster_id, similarity))

        # Сортируем по убыванию сходства
        similarities.sort(key=lambda x: x[1], reverse=True)
        return similarities[:k]

    # Функции сохранения:
    # ??? Доработать!
    def save(self, filepath: str):
        """
        Сохраняет граф в файл (без FAISS индекса, он будет перестроен).
        Должна всегда вызываться перед закрытием процесса.
        """
        global cluster_threshold
        data = {
            "clusters": {},
            "embeddings": self.embeddings,
            "cluster_labels": self.cluster_labels,
            "next_cluster_id": self.next_cluster_id,
            "cluster_threshold": cluster_threshold,  # если нужно
        }
        # ClusterNode не сериализуется pickle по умолчанию (dataclass – да),
        # но лучше преобразовать в dict
        for cid, node in self.clusters.items():
            data["clusters"][cid] = {
                "id": node.id,
                "centroid": node.centroid,
                "nodes": node.image_paths,
                "size": node.size,
            }
        with open(filepath, "wb") as f:
            pickle.dump(data, f)
        lib_logger.info(f"Граф сохранён в {filepath}")

    def load(self, filepath: str):
        """Загружает граф из файла и перестраивает FAISS индекс. Должна вызываться при загрузке файла."""
        global cluster_threshold
        try:
            with open(filepath, "rb") as f:
                data = pickle.load(f)

            self.embeddings = data["embeddings"]
            self.cluster_labels = data["cluster_labels"]
            self.next_cluster_id = data["next_cluster_id"]
            cluster_threshold = data.get("cluster_threshold", 0.75)

            # Восстанавливаем кластеры
            self.clusters = {}
            for cid, node_dict in data["clusters"].items():
                node = ClusterNode(
                    id=node_dict["id"],
                    centroid=node_dict["centroid"],
                    nodes=node_dict["image_paths"],
                    size=node_dict["size"],
                )
                self.clusters[cid] = node

            # Перестраиваем FAISS индекс
            if len(self.embeddings) > 0:
                # Нормализуем (если ещё не нормализованы)
                emb_norm = self.embeddings.copy()
                faiss.normalize_L2(emb_norm)
                self.index = faiss.IndexFlatIP(emb_norm.shape[1])
                self.index.add(emb_norm)
            else:
                self.index = None

            lib_logger.info(
                f"Граф загружен из {filepath}, кластеров: {len(self.clusters)}"
            )
        except Exception as e:
            lib_logger.info(
                f"Граф не найден по пути {filepath} ({e}), будет создан новый!"
            )

    """???
    Пример использования:
    graph = EmbeddingGraph()
    graph.build_from_images(list_of_paths)
    graph.save("embedding_graph.pkl")

    # При следующем запуске:
    new_graph = EmbeddingGraph()
    new_graph.load("embedding_graph.pkl")
    # Теперь можно вызывать find_similar_clusters, add_image и т.д.
    """


# Основной граф.
embedding_graph = EmbeddingGraph()
embedding_graph.load("embedding_graph.pkl")

# Вспомогательный граф, выступающий буфером между запросов.
# Когда в систему приходит новый материал - анализируются его параметры
# И отправляются запросы во внешнюю систему на генерацию рендеров для
# сгенерированных во время анализа
material_graph = MaterialGraph()
