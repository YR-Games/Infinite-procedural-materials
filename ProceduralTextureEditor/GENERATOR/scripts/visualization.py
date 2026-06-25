"""
lib/visualization.py
Визуализация результатов
"""

import matplotlib.pyplot as plt
import networkx as nx
from PIL import Image

from scripts.embedding_graph import AbstractGraph


def visualize_graph(graph):
    """
    Визуализирует граф кластеров.
    """
    pos = nx.spring_layout(graph.graph)
    nx.draw(graph.graph, pos, with_labels=True)
    plt.show()


def visualize_clusters(graph, cluster_root):
    """
    Визуализирует кластер с миниатюрами изображений.
    """
    # Получить узлы кластера
    neighbors = list(graph.graph.neighbors(cluster_root)) + [cluster_root]
    fig, axes = plt.subplots(1, len(neighbors), figsize=(10, 5))
    for i, node in enumerate(neighbors):
        img = Image.open(node).resize((100, 100))
        axes[i].imshow(img)
        axes[i].set_title(node.split("/")[-1])
    plt.show()


def visualize_similarity(path1, path2, similarity):
    """
    Визуализирует расстояние между двумя изображениями.
    """
    fig, axes = plt.subplots(1, 2)
    axes[0].imshow(Image.open(path1))
    axes[1].imshow(Image.open(path2))
    plt.suptitle(f"Сходство: {similarity}")
    plt.show()


def visualize_clusters(graph: AbstractGraph, output_dir: str = "data/visualizations"):
        """
        Универсальный метод для визуализации графов и входящих в них нод:
        для каждого кластера создаёт коллаж из миниатюр,
        а также общую MDS-карту расположения кластеров.

        ??? Устарел и недописан!

        Args:
            output_dir: директория для сохранения изображений
        """
        import os

        import matplotlib.pyplot as plt
        import numpy as np
        from PIL import Image

        from .utils import tensor_to_pil

        os.makedirs(output_dir, exist_ok=True)

        if not self.clusters:
            lib_logger.warning("⚠️Нет кластеров для визуализации.")
            return

        cluster_files = []
        centroids = []

        # Сортируем кластеры по id для стабильности
        sorted_clusters = sorted(self.clusters.items(), key=lambda x: x[0])

        for cluster_id, cluster_node in tqdm(
            sorted_clusters, desc="Визуализация кластеров"
        ):
            # Пути к изображениям в кластере
            paths = cluster_node.image_paths
            if not paths:
                continue

            # Загружаем миниатюры
            images = []
            for path in paths:
                try:
                    # Применяем трансформацию (ресайз + тензор)
                    # Превращаем обратно в PIL для вставки
                    images.append(  # type: ignore
                        tensor_to_pil(
                            load_and_transform_image(
                                path,
                                self.preview_image_size,
                                False,  # type: ignore
                            )
                        )
                    )
                except Exception as e:
                    lib_logger.error(f"💥Ошибка загрузки {path}: {e}")

            if not images:
                continue

            # Создаём сетку из миниатюр
            cols = int(np.ceil(np.sqrt(len(images))))
            rows = int(np.ceil(len(images) / cols))
            cluster_img = Image.new(
                "RGB",
                (cols * self.preview_image_size, rows * self.preview_image_size),
                (255, 255, 255),
            )
            for i, img_pil in enumerate(images):
                x = (i % cols) * self.preview_image_size
                y = (i // cols) * self.preview_image_size
                cluster_img.paste(img_pil, (x, y))

            # Сохраняем коллаж
            cluster_filename = f"cluster_{cluster_id}.png"
            cluster_img.save(os.path.join(output_dir, cluster_filename))
            cluster_files.append(cluster_filename)
            centroids.append(cluster_node.centroid)

        # Построение MDS карты расположения кластеров
        n_clusters = len(centroids)
        if n_clusters == 0:
            return

        # Вычисляем попарные расстояния между центроидами
        distances = np.zeros((n_clusters, n_clusters))
        for i in range(n_clusters):
            for j in range(i + 1, n_clusters):
                # Косинусное расстояние
                sim = np.dot(centroids[i], centroids[j])
                dist = 1.0 - sim
                distances[i, j] = dist
                distances[j, i] = dist

        # MDS для 2D размещения
        if n_clusters > 1:
            from sklearn.manifold import MDS

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
        plt.savefig(os.path.join(output_dir, "overview.png"), bbox_inches="tight")
        plt.close()