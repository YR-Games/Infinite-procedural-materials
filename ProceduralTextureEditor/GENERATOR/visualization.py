"""
lib/visualization.py
Визуализация результатов
"""

import matplotlib.pyplot as plt
import networkx as nx
from PIL import Image


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
