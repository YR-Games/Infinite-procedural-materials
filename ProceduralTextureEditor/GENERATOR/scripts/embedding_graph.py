"""
scripts/embedding_graph.py
Структура данных для эффективного хранения и поиска кластеров эмбеддингов.
"""

import pickle
from dataclasses import dataclass
from functools import lru_cache
from typing import Dict, List, Tuple

import faiss
import numpy as np
from sklearn.cluster import DBSCAN

from .logger import lib_logger
from .models_manager import get_embedding

# Глобальные параметры.
cluster_threshold: float = 0.9


# Вспомогательные классы.
@dataclass
class RenderNode:
    """Узел графа, связывающий Материал с эмбеддингом."""

    material: str
    embedding: np.ndarray

    def __init__(self, material: str, embedding: np.ndarray) -> None:
        self.material = material
        self.embedding = embedding


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

        self.index = None  # FAISS индекс для центроидов
        self._cluster_ids = []  # список id кластеров в порядке индекса

    @lru_cache(maxsize=1000)
    def _get_norm_embedding(self, image: str) -> np.ndarray:
        """Возвращает нормализованный эмбеддинг по пути к изображению."""
        embedding = get_embedding(image).numpy().squeeze()
        return embedding / np.linalg.norm(embedding)  # Нормализуем

    def _rebuild_index(self):
        """Перестраивает FAISS индекс из центроидов всех кластеров."""
        if not self.clusters:
            self.index = None
            self._cluster_ids = []
            return

        self._cluster_ids = list(self.clusters.keys())
        centroids = np.array(
            [self.clusters[cid].centroid for cid in self._cluster_ids], dtype=np.float32
        )
        faiss.normalize_L2(centroids)
        dim = centroids.shape[1]
        self.index = faiss.IndexFlatIP(dim)
        self.index.add(centroids)

    def _add_centroid_to_index(self, centroid: np.ndarray, cluster_id: int):
        """Добавляет один центроид в существующий индекс."""
        if self.index is None:
            dim = centroid.shape[0]
            self.index = faiss.IndexFlatIP(dim)
            self._cluster_ids = []
        centroid_norm = centroid.astype(np.float32).reshape(1, -1)
        faiss.normalize_L2(centroid_norm)
        self.index.add(centroid_norm)
        self._cluster_ids.append(cluster_id)

    def find_similar_clusters(self, image: str, k: int = 0) -> List[Tuple[str, float]]:
        """
        Находит до k (по умолчанию 10, но не более 10) наиболее похожих материалов,
        рассматривая не более 4 кластеров с наиболее похожими центроидами.
        Возвращает список кортежей (material, similarity) отсортированных по убыванию similarity.
        """
        limit = 10 if k <= 0 else min(k, 10)
        max_clusters = 4

        embedding = self._get_norm_embedding(image)
        if self.index is None or self.index.ntotal == 0:
            return []

        query = embedding.astype(np.float32).reshape(1, -1)
        faiss.normalize_L2(query)
        num_to_search = min(max_clusters, self.index.ntotal)
        similarities, indices = self.index.search(query, num_to_search)

        candidates = []
        for i in range(num_to_search):
            idx = indices[0][i]
            if idx < len(self._cluster_ids):
                cid = self._cluster_ids[idx]
                cluster = self.clusters.get(cid)
                if cluster is None:
                    continue
                # Для каждого узла в кластере вычисляем точное косинусное сходство с запросом
                for node in cluster.nodes:
                    exact_sim = float(np.dot(embedding, node.embedding))
                    candidates.append((node.material, exact_sim))

        # Сортируем по убыванию точного сходства и обрезаем до лимита
        candidates.sort(key=lambda x: x[1], reverse=True)
        return candidates[:limit]


# Основные графы:
class MaterialGraph(AbstractGraph):
    """
    Граф, каждый элемент которого - RenderNode,
    эмбеддинги которых удалены друг от друга
    на расстояние не менее cluster_threshold.

    Стуктура нод такая:
    ClusterNode <-содержит единственный- RenderNode.
    """

    def __init__(self):
        super().__init__()
        self.material: str = ""

    def _clear(self):
        """Очищает граф."""
        self.clusters.clear()
        self.next_cluster_id = 0
        self.index = None
        self._cluster_ids = []
        self.material = ""

    def add_render(self, image: str, material: str) -> bool:
        """
        Добавляет рендер в граф Материала и возвращает True, если он добавлен в новый кластер,
        False - пропущен, так как слишком похож на уже добавленные.
        """
        global cluster_threshold

        if material != self.material:
            self._clear()
            self.material = material

        embedding = self._get_norm_embedding(image)

        # Проверяем, есть ли уже похожие кластеры (по максимальному сходству)
        if self.index is not None and self.index.ntotal > 0:
            query = embedding.astype(np.float32).reshape(1, -1)
            faiss.normalize_L2(query)
            similarities, _ = self.index.search(query, 1)
            max_sim = similarities[0][0]
            if max_sim >= cluster_threshold:
                return False

        # Создаём новый кластер
        cluster_id = self.next_cluster_id
        self.next_cluster_id += 1
        node = RenderNode(material, embedding)
        cluster = ClusterNode(id=cluster_id, centroid=embedding, nodes=[node], size=1)
        self.clusters[cluster_id] = cluster

        # Добавляем центроид в индекс
        self._add_centroid_to_index(embedding, cluster_id)
        return True


class EmbeddingGraph(AbstractGraph):
    """
    Граф для хранения и поиска кластеров эмбеддингов.
    Создаётся путём добавления MaterialGraph.
    """

    def __init__(self):
        super().__init__()

    def add_nodes(self, material_graph: MaterialGraph):
        """
        Дополняет/создаёт кластеры с использованием DBSCAN из графа рендеров материала.
        """
        global cluster_threshold

        lib_logger.info("Объединение графов... ⚙️")

        # Собираем все эмбеддинги и соответствующие RenderNode из material_graph
        embeddings_list = []
        nodes_list = []  # список RenderNode
        for cluster in material_graph.clusters.values():
            # каждый кластер содержит один RenderNode
            if cluster.nodes:
                node = cluster.nodes[0]
                embeddings_list.append(node.embedding)
                nodes_list.append(node)

        if not embeddings_list:
            lib_logger.info("Нет данных для кластеризации.")
            return

        X = np.array(embeddings_list, dtype=np.float32)
        faiss.normalize_L2(X)  # на всякий случай?

        # DBSCAN с косинусным расстоянием
        eps = 1 - cluster_threshold
        db = DBSCAN(eps=eps, min_samples=1, metric="cosine")
        labels = db.fit_predict(X)

        # Группируем по меткам
        unique_labels = set(labels)
        for label in unique_labels:
            indices = np.where(labels == label)[0]
            cluster_nodes = [nodes_list[i] for i in indices]

            if label == -1:
                # Шум – создаём отдельный кластер для каждого элемента
                for node in cluster_nodes:
                    cluster_id = self.next_cluster_id
                    self.next_cluster_id += 1
                    centroid = node.embedding
                    cluster = ClusterNode(
                        id=cluster_id, centroid=centroid, nodes=[node], size=1
                    )
                    self.clusters[cluster_id] = cluster
            else:
                # Вычисляем центроид кластера
                centroids = np.array([node.embedding for node in cluster_nodes])
                centroid = np.mean(centroids, axis=0)
                centroid = centroid / np.linalg.norm(centroid)
                cluster_id = self.next_cluster_id
                self.next_cluster_id += 1
                cluster = ClusterNode(
                    id=cluster_id,
                    centroid=centroid,
                    nodes=cluster_nodes,
                    size=len(cluster_nodes),
                )
                self.clusters[cluster_id] = cluster

        # Перестраиваем индекс
        self._rebuild_index()
        lib_logger.info(f"Создано {len(self.clusters)} кластеров 🗜️")
        self.save()

    # Функции сохранения:
    def save(self, filepath: str = "embedding_graph.pkl"):
        """
        Сохраняет граф в файл (без FAISS индекса, он будет перестроен).
        """
        global cluster_threshold
        data = {
            "clusters": self.clusters,
            "next_cluster_id": self.next_cluster_id,
            "cluster_threshold": cluster_threshold,
        }
        with open(filepath, "wb") as f:
            pickle.dump(data, f)
        lib_logger.info(f"Граф сохранён в {filepath}")

    def load(self, filepath: str = "embedding_graph.pkl"):
        """Загружает граф из файла и перестраивает FAISS индекс. Должна вызываться при загрузке файла."""
        global cluster_threshold
        try:
            with open(filepath, "rb") as f:
                data = pickle.load(f)

            self.clusters = data["clusters"]
            self.next_cluster_id = data["next_cluster_id"]
            cluster_threshold = data.get("cluster_threshold", 0.75)

            # Перестраиваем FAISS индекс
            self._rebuild_index()
            lib_logger.info(
                f"Граф загружен из {filepath}, кластеров: {len(self.clusters)}"
            )
        except Exception as e:
            lib_logger.info(
                f"Граф не найден по пути {filepath} ({e}), будет создан новый!"
            )
            self.clusters = {}
            self.next_cluster_id = 0
            self.index = None
            self._cluster_ids = []


# Основной граф.
embedding_graph = EmbeddingGraph()
embedding_graph.load()

# Вспомогательный граф, выступающий буфером между запросов.
material_graph = MaterialGraph()
