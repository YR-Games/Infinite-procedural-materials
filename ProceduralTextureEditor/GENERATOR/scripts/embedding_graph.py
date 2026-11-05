"""
scripts/embedding_graph.py
Структуры данных для эффективного хранения и поиска кластеров эмбеддингов.
Не потокобезопасен! Многопоточное выполнение допустимо ТОЛЬКО для MaterialGraph!
Расчитан на python 3.13.5
"""

import pickle
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

import faiss
import numpy as np

from .logger import lib_logger
from .models_manager import get_embedding

# Глобальные параметры.
cluster_threshold: float = 0.75
all_added_materials: list[str] = []


# Вспомогательные классы.
@dataclass(slots=True)
class RenderNode:
    """Узел графа, связывающий Материал с эмбеддингом."""

    material_id: int
    """Уникальный индекс высушенного материала (без параметров, только структура)"""
    material_params: str
    """Материал с параметрами"""
    embedding: np.ndarray
    """Эмбеддинг рендера при параметрах material_params"""


@dataclass(slots=True)
class ClusterNode:
    """Узел кластера в графе."""

    id: int
    centroid: np.ndarray
    nodes: list[RenderNode]
    size: int
    sum_embedding: np.ndarray


class AbstractGraph:
    def __init__(self):
        self.clusters: dict[int, ClusterNode] = {}
        self.next_cluster_id = 0

        self.index: faiss.IndexFlatIP | None = None  # FAISS индекс для центроидов
        self._cluster_ids: list[int] = []  # список id кластеров в порядке индекса

    @lru_cache(maxsize=1000)
    @staticmethod
    def _get_norm_embedding(image: str) -> np.ndarray:
        """Возвращает нормализованный эмбеддинг по строковому представлению изображения."""
        vec = get_embedding(image).numpy().squeeze()
        vec = vec.astype(np.float32, copy=False)
        vec = vec / np.linalg.norm(vec)  # уже нормирован, но пока 1D
        return vec.reshape(1, -1)  # (1, d) float32

    def _rebuild_index(self):
        """Перестраивает FAISS индекс из центроидов всех кластеров."""
        if not self.clusters:
            self.index = None
            self._cluster_ids = []
            return

        self._cluster_ids = list(self.clusters.keys())
        centroids = np.vstack(
            [self.clusters[cid].centroid for cid in self._cluster_ids]
        ).astype(np.float32, copy=False)
        dim = centroids.shape[1]
        self.index = faiss.IndexFlatIP(dim)
        self.index.add(centroids)

    def _add_centroid_to_index(self, centroid: np.ndarray, cluster_id: int):
        """Добавляет один центроид в существующий индекс."""
        if self.index is None:
            self.index = faiss.IndexFlatIP(centroid.shape[-1])
            self._cluster_ids = []
        self.index.add(centroid.astype(np.float32, copy=False))
        self._cluster_ids.append(cluster_id)

    def find_similar_clusters(
        self, image: str, limit: int = 10
    ) -> list[tuple[str, float]]:
        """
        Находит до k (по умолчанию не более 10) наиболее похожих материалов,
        рассматривая не более 5 кластеров с наиболее похожими центроидами.
        Возвращает список кортежей (material_params, similarity) отсортированных по убыванию similarity.
        """
        max_clusters = 5

        embedding = AbstractGraph._get_norm_embedding(image)
        if self.index is None or self.index.ntotal == 0:
            return []

        num_to_search = min(max_clusters, self.index.ntotal)
        _, indices = self.index.search(embedding, num_to_search)

        candidates: list[tuple[str, float]] = []
        for i in range(num_to_search):
            idx = indices[0][i]
            if 0 <= idx < len(self._cluster_ids):
                cid: int = self._cluster_ids[idx]  # type: ignore
                cluster = self.clusters.get(cid)  # type: ignore
                if cluster is None:
                    continue
                # Для каждого узла в кластере вычисляем точное косинусное сходство с запросом
                for node in cluster.nodes:
                    exact_sim = float(np.dot(embedding[0], node.embedding[0]))
                    candidates.append((node.material_params, exact_sim))

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
        self.material_id: int = -1
        self.current_material: str = ""

    def _clear(self):
        """Очищает граф."""
        self.clusters.clear()
        self.next_cluster_id = 0
        self.index = None
        self._cluster_ids = []
        self.material_id = -1

    def add_render(self, image: str, material: str, material_params: str) -> bool:
        """
        Добавляет рендер в граф Материала и возвращает True, если он добавлен в новый кластер,
        False - пропущен, так как слишком похож на уже добавленные.

        * material не может меняться во время добавления рендеров одного материала,
        а все материалы добавляются последовательно.
        """

        if material != self.current_material:
            self._clear()
            # Обновляем список добавленных материалов и сохраняем его индекс
            self.material_id = len(all_added_materials)
            all_added_materials.append(material)
            self.current_material = material

        embedding = AbstractGraph._get_norm_embedding(image)

        # Проверяем, есть ли уже похожие кластеры (по максимальному сходству)
        if self.index is not None and self.index.ntotal > 0:
            similarities, _ = self.index.search(embedding, 1)
            max_sim = similarities[0][0]
            if max_sim >= cluster_threshold:
                return False

        # Создаём новый кластер
        cluster_id = self.next_cluster_id
        self.next_cluster_id += 1
        node = RenderNode(self.material_id, material_params, embedding)
        cluster = ClusterNode(
            id=cluster_id,
            centroid=embedding,
            nodes=[node],
            size=1,
            sum_embedding=embedding.copy(),
        )
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

    def add_nodes(self, material_graph: MaterialGraph, save: bool = True):
        """
        Дополняет граф эмбеддингов нодами из графа материала.
        Близкие ноды объединяются в существующие кластеры,
        далёкие создают новые кластеры.
        """

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
                similarities, indices = self.index.search(embedding, 1)
                max_sim = similarities[0][0]

                if max_sim >= cluster_threshold:
                    # Добавляем в существующий кластер
                    cluster_idx: int = indices[0][0]
                    if 0 <= cluster_idx < len(self._cluster_ids):
                        cluster_id = self._cluster_ids[cluster_idx]
                        cluster = self.clusters[cluster_id]

                        # Точное обновление центроидf через хранимую сумму с учётом нового элемента
                        cluster.sum_embedding += embedding  # (1,d) += (1,d)
                        cluster.size += 1
                        cluster.nodes.append(node)
                        cluster.centroid = cluster.sum_embedding / np.linalg.norm(
                            cluster.sum_embedding
                        )

                        added_to_existing += 1
                        continue

            # Если похожего кластера нет - создаём новый
            cluster_id = self.next_cluster_id
            self.next_cluster_id += 1

            # Центроид уже нормализован
            centroid = embedding.copy()

            cluster = ClusterNode(
                id=cluster_id,
                centroid=centroid,
                nodes=[node],
                size=1,
                sum_embedding=embedding.copy(),
            )
            self.clusters[cluster_id] = cluster
            new_clusters_count += 1

            # Добавляем новый центроид в индекс
            self._add_centroid_to_index(centroid, cluster_id)

        # Перестраиваем индекс
        if new_clusters_count > 0 or added_to_existing > 0:
            self._rebuild_index()
            lib_logger.info(
                f"Добавлено {new_clusters_count} новых кластеров, "
                f"{added_to_existing} нод добавлено в существующие кластеры 🗜️"
            )
            if save:
                self.save()
        else:
            lib_logger.info("Нет изменений в графе")

    # Функции сохранения:
    def save(self, filepath: str = "embedding_graph.pkl"):
        """
        Сохраняет граф в файл (без FAISS индекса, он будет перестроен).
        """
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
        except Exception as e:  # noqa: BLE001
            lib_logger.info(
                f"Граф не найден по пути {filepath} ({e}), будет создан новый!"
            )
            self.clusters = {}
            self.next_cluster_id = 0
            self.index = None
            self._cluster_ids = []


def is_material_do_not_added(material: str) -> bool:
    """Возвращает True, есл иматериал ещё не добавлен."""
    return material not in all_added_materials


# Основной граф.
embedding_graph = EmbeddingGraph()
embedding_graph.load()

# Вспомогательный граф, выступающий буфером между запросов.
material_graph = MaterialGraph()
