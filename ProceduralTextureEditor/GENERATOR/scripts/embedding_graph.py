"""
scripts/embedding_graph.py
Структура данных для эффективного хранения и поиска кластеров эмбеддингов.
"""

import pickle
from dataclasses import dataclass
from functools import lru_cache

import faiss
import numpy as np

from .logger import lib_logger
from .models_manager import get_embedding

# Глобальные параметры.
cluster_threshold: float = 0.75
all_added_materials: list[str] = []


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
    nodes: list[RenderNode]
    size: int


class AbstractGraph:
    def __init__(self):
        self.clusters: dict[int, ClusterNode] = {}
        self.next_cluster_id = 0

        self.index = None  # FAISS индекс для центроидов
        self._cluster_ids: list[int] = []  # список id кластеров в порядке индекса

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

    def find_similar_clusters(
        self, image: str, limit: int = 10
    ) -> list[tuple[str, float]]:
        """
        Находит до k (по умолчанию 10, но не более 10) наиболее похожих материалов,
        рассматривая не более 4 кластеров с наиболее похожими центроидами.
        Возвращает список кортежей (material, similarity) отсортированных по убыванию similarity.
        """
        max_clusters = 5

        embedding = self._get_norm_embedding(image)
        if self.index is None or self.index.ntotal == 0:
            return []

        query = embedding.astype(np.float32).reshape(1, -1)
        faiss.normalize_L2(query)
        num_to_search = min(max_clusters, self.index.ntotal)
        similarities, indices = self.index.search(query, num_to_search)

        candidates: list[tuple[str, float]] = []
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

    def add_render(self, image: str, material: str, material_params: str) -> bool:
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
            query = embedding.astype(np.float32).reshape(
                1, -1
            )  # ??? стразу приводить эмбеддинг к такому виду и в нём и сохранять!
            faiss.normalize_L2(query)
            similarities, _ = self.index.search(query, 1)
            max_sim = similarities[0][0]
            if max_sim >= cluster_threshold:
                return False

        # Создаём новый кластер
        cluster_id = self.next_cluster_id
        self.next_cluster_id += 1
        node = RenderNode(material_params, embedding)
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
        Дополняет граф эмбеддингов нодами из графа материала.
        Близкие ноды объединяются в существующие кластеры,
        далёкие создают новые кластеры.
        """
        global cluster_threshold, all_added_materials

        lib_logger.info("Объединение графов... ⚙️")

        # Собираем все RenderNode из material_graph
        render_nodes: list[RenderNode] = []
        for cluster in material_graph.clusters.values():
            if cluster.nodes:
                render_nodes.extend(cluster.nodes)

        if not render_nodes:
            lib_logger.warning("Нет данных для добавления⚠️")
            return

        new_clusters_count: int = 0
        added_to_existing: int = 0

        for node in render_nodes:
            embedding = node.embedding

            # Проверяем, есть ли похожий кластер в embedding_graph
            if self.index is not None and self.index.ntotal > 0:
                query = embedding.astype(np.float32).reshape(1, -1)
                similarities, indices = self.index.search(query, 1)
                max_sim = similarities[0][0]

                if max_sim >= cluster_threshold:
                    # Добавляем в существующий кластер
                    cluster_idx: int = indices[0][0]
                    if cluster_idx < len(self._cluster_ids):
                        cluster_id = self._cluster_ids[cluster_idx]
                        cluster = self.clusters[cluster_id]

                        # Обновляем центроид с учётом нового элемента
                        old_centroid = cluster.centroid
                        # Добавляем новый элемент в кластер
                        cluster.nodes.append(node)
                        cluster.size += 1

                        # Пересчитываем центроид (инкрементально)
                        new_centroid = (
                            old_centroid * (cluster.size - 1) + embedding
                        ) / cluster.size
                        new_centroid = new_centroid / np.linalg.norm(new_centroid)
                        cluster.centroid = new_centroid

                        added_to_existing += 1
                        continue

            # Если похожего кластера нет - создаём новый
            cluster_id = self.next_cluster_id
            self.next_cluster_id += 1

            # Нормализуем центроид ??? если хранить шготовые эмбеддинги - лишнее, так как центройд и будет эмбеддингом
            centroid = embedding.copy()
            centroid = centroid / np.linalg.norm(centroid)

            cluster = ClusterNode(
                id=cluster_id, centroid=centroid, nodes=[node], size=1
            )
            self.clusters[cluster_id] = cluster
            new_clusters_count += 1

        # Обновляем список добавленных материалов
        if material_graph.material not in all_added_materials:
            all_added_materials.append(material_graph.material)

        # Перестраиваем индекс
        if new_clusters_count > 0 or added_to_existing > 0:
            self._rebuild_index()
            lib_logger.info(
                f"Добавлено {new_clusters_count} новых кластеров, "
                f"{added_to_existing} нод добавлено в существующие кластеры 🗜️"
            )
            self.save()
        else:
            lib_logger.info("Нет изменений в графе")

        """
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
            cluster_nodes: list[RenderNode] = [nodes_list[i] for i in indices]

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
                centroid = cluster_nodes[0].embedding.copy()
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
        all_added_materials.append(nodes_list[0].material)
        self.save()
        """

    # Функции сохранения:
    def save(self, filepath: str = "embedding_graph.pkl"):
        """
        Сохраняет граф в файл (без FAISS индекса, он будет перестроен).
        """
        global cluster_threshold, all_added_materials
        data: dict[str, Any] = {
            "clusters": self.clusters,
            "next_cluster_id": self.next_cluster_id,
            "cluster_threshold": cluster_threshold,
            "all_added_materials": all_added_materials,
        }
        with open(filepath, "wb") as f:
            pickle.dump(data, f)
        lib_logger.info(f"Граф сохранён в {filepath}")

    def load(self, filepath: str = "embedding_graph.pkl"):
        """Загружает граф из файла и перестраивает FAISS индекс. Должна вызываться при загрузке файла."""
        global cluster_threshold, all_added_materials
        try:
            with open(filepath, "rb") as f:
                data = pickle.load(f)

            self.clusters = data["clusters"]
            self.next_cluster_id = data["next_cluster_id"]
            cluster_threshold = data.get("cluster_threshold", 0.75)
            all_added_materials = data.get("all_added_materials", [])

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


def is_material_already_added(material: str) -> bool:
    return material not in all_added_materials


# Основной граф.
embedding_graph = EmbeddingGraph()
embedding_graph.load()

# Вспомогательный граф, выступающий буфером между запросов.
material_graph = MaterialGraph()
