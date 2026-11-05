# pyright: reportUnknownMemberType=false
# reportUnknownMemberType отключён для этого файла, потому что стабы matplotlib
# объявляют **kwargs: Unknown, из-за чего каждый вызов plt.* и ax.* даёт эту
# диагностику. См. https://github.com/microsoft/pyright/issues/2923

"""
scripts/visualization.py
Визуализирует:
    1. Внутреннюю структуру графа эмбеддингов;
    2. Распределение эмбеддингов материалов в пространстве: изображение с точками
       в двумерном пространстве расстояний, подписанными номерами, и файлы
       с RenderNode.material_params, названные соответствующими номерами, все точки
       одного RenderNode.material_id покрашены в один цвет, изображение сопровождается
       легендой и масштабом.
"""

import os
import sys
from typing import Any

import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
from matplotlib.lines import Line2D
from sklearn.manifold import MDS

# Импорт, работающий и как `python -m scripts.visualization`,
# и как `python scripts/visualization.py`.
try:
    from .embedding_graph import (
        AbstractGraph,
        ClusterNode,
        RenderNode,
        embedding_graph,
    )
except ImportError:
    _here: str = os.path.dirname(os.path.abspath(__file__))
    _parent: str = os.path.dirname(_here)
    if _parent not in sys.path:
        sys.path.insert(0, _parent)
    from scripts.embedding_graph import (
        AbstractGraph,
        ClusterNode,
        RenderNode,
        embedding_graph,
    )


# ---------------------------------------------------------------------------
# Вспомогательные функции
# ---------------------------------------------------------------------------
def get_next_visualization_dir(base_dir: str = "data") -> str:
    """
    Возвращает путь к следующей по номеру папке визуализации
    ``<base_dir>/visualizations_<N>`` и создаёт её.
    """
    os.makedirs(base_dir, exist_ok=True)
    idx: int = 1
    while True:
        candidate: str = os.path.join(base_dir, f"visualizations_{idx}")
        if not os.path.exists(candidate):
            os.makedirs(candidate, exist_ok=True)
            return candidate
        idx += 1


def _collect_render_nodes(graph: AbstractGraph) -> list[RenderNode]:
    """Собирает все RenderNode из всех кластеров графа."""
    nodes: list[RenderNode] = []
    for cluster in graph.clusters.values():
        nodes.extend(cluster.nodes)
    return nodes


# ---------------------------------------------------------------------------
# 1. Внутренняя структура графа эмбеддингов
# ---------------------------------------------------------------------------
def visualize_graph(
    graph: AbstractGraph,
    output_dir: str,
    sim_threshold: float = 0.7,
) -> None:
    """
    Визуализирует внутреннюю структуру графа эмбеддингов.

    Узлы соответствуют кластерам (размер узла пропорционален числу
    RenderNode в кластере). Между кластерами, косинусное сходство
    центроидов которых не меньше ``sim_threshold``, добавляются рёбра.
    Результат сохраняется в ``<output_dir>/graph_structure.png``.
    """
    G: nx.Graph[int, dict[str, Any], dict[str, Any]] = nx.Graph()

    cid: int
    cluster: ClusterNode
    for cid, cluster in graph.clusters.items():
        G.add_node(cid, size=cluster.size)

    ids: list[int] = list(graph.clusters.keys())
    if len(ids) > 1:
        centroids: np.ndarray = np.array(
            [graph.clusters[c].centroid for c in ids], dtype=np.float32
        )
        norms: np.ndarray = np.linalg.norm(centroids, axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        centroids = centroids / norms
        sims: np.ndarray = centroids @ centroids.T

        i: int
        j: int
        for i in range(len(ids)):
            for j in range(i + 1, len(ids)):
                if float(sims[i, j]) >= sim_threshold:
                    G.add_edge(ids[i], ids[j], weight=float(sims[i, j]))

    if G.number_of_nodes() == 0:
        print("Граф пуст — визуализация невозможна.")
        return

    pos: dict[int, np.ndarray] = nx.spring_layout(G, seed=42, weight="weight")
    sizes: list[float] = [
        200.0 + 80.0 * float(G.nodes[n].get("size", 1)) for n in G.nodes
    ]

    plt.figure(figsize=(10, 10))
    nx.draw(
        G,
        pos,
        with_labels=True,
        node_size=sizes,
        node_color="lightsteelblue",
        edge_color="gray",
        font_size=8,
        width=1.0,
    )
    plt.title("Внутренняя структура графа эмбеддингов")
    plt.axis("off")

    output_path: str = os.path.join(output_dir, "graph_structure.png")
    plt.savefig(output_path, bbox_inches="tight")
    plt.show()


# ---------------------------------------------------------------------------
# 2. Распределение эмбеддингов материалов
# ---------------------------------------------------------------------------
def visualize_embedding_distribution(
    graph: AbstractGraph,
    output_dir: str,
    image_name: str = "embedding_distribution.png",
) -> None:
    """
    Визуализирует распределение эмбеддингов материалов в двумерном
    пространстве расстояний (MDS по матрице косинусных расстояний).

    Каждая точка соответствует одному RenderNode и подписана меткой
    ``<material_id>_<ordinal>``, где ``ordinal`` — порядковый номер
    RenderNode внутри данного ``material_id``. Для каждой точки в
    ``output_dir`` сохраняется файл ``<material_id>_<ordinal>.txt``
    с содержимым ``RenderNode.material_params``. Точки, относящиеся
    к одному и тому же ``RenderNode.material_id``, окрашены в один
    цвет. Изображение сопровождается легендой (метки
    ``<material_id>_<ordinal>``) и масштабом осей в единицах
    косинусного расстояния.
    """
    os.makedirs(output_dir, exist_ok=True)

    nodes: list[RenderNode] = _collect_render_nodes(graph)
    if not nodes:
        print("Нет RenderNode — визуализация невозможна.")
        return

    # Формируем метки <material_id>_<ordinal>, где ordinal — счётчик
    # внутри данного material_id.
    material_ordinals: dict[int, int] = {}
    labels: list[str] = []
    material_ids: list[int] = []
    node: RenderNode
    for node in nodes:
        mid: int = node.material_id
        material_ordinals[mid] = material_ordinals.get(mid, 0) + 1
        ordinal: int = material_ordinals[mid]
        labels.append(f"{mid}_{ordinal}")
        material_ids.append(mid)

    # Нормализуем эмбеддинги (на случай, если где-то сохранились ненормализованные).
    embeddings: np.ndarray = np.array([n.embedding for n in nodes], dtype=np.float32)
    norms: np.ndarray = np.linalg.norm(embeddings, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    embeddings = embeddings / norms

    # Матрица попарных косинусных расстояний.
    sim: np.ndarray = embeddings @ embeddings.T
    dist: np.ndarray = np.clip(1.0 - sim, 0.0, None)
    np.fill_diagonal(dist, 0.0)

    # 2D-размещение (MDS).
    coords: np.ndarray
    if len(nodes) > 1:
        mds: MDS = MDS(
            n_components=2,
            dissimilarity="precomputed",
            random_state=42,
            normalized_stress="auto",
        )
        coords = mds.fit_transform(dist)
    else:
        coords = np.zeros((1, 2), dtype=np.float32)

    # Цвета по material_id.
    unique_material_ids: list[int] = list(dict.fromkeys(material_ids))
    cmap = plt.get_cmap("tab20")
    mid_colors: dict[int, tuple[float, float, float, float]] = {
        mid: cmap(i % 20) for i, mid in enumerate(unique_material_ids)
    }

    # Текстовые файлы <material_id>_<ordinal>.txt с содержимым material_params.
    idx: int
    label: str
    for idx, label in enumerate(labels):
        path: str = os.path.join(output_dir, f"{label}.txt")
        with open(path, "w", encoding="utf-8") as f:
            f.write(nodes[idx].material_params)

    # Собственно график.
    _, ax = plt.subplots(figsize=(14, 14))
    i: int
    for i in range(len(nodes)):
        x: float = float(coords[i, 0])
        y: float = float(coords[i, 1])
        color: tuple[float, float, float, float] = mid_colors[material_ids[i]]
        ax.scatter(
            x,
            y,
            s=110,
            color=color,
            edgecolors="black",
            linewidths=0.5,
            zorder=3,
        )
        ax.annotate(
            labels[i],
            (x, y),
            fontsize=8,
            ha="center",
            va="center",
            zorder=4,
        )

    # Легенда: по записи на каждую точку с меткой <material_id>_<ordinal>.
    handles: list[Line2D] = []
    for i in range(len(nodes)):
        color = mid_colors[material_ids[i]]
        handle: Line2D = Line2D(
            [0],
            [0],
            marker="o",
            color="w",
            markerfacecolor=color,
            markersize=8,
            label=labels[i],
        )
        handles.append(handle)
    ax.legend(
        handles=handles,
        loc="upper right",
        fontsize=7,
        title="<material_id>_<ordinal>",
        framealpha=0.9,
    )

    # Масштаб: оси с подписями и сеткой — это и есть масштаб
    # в единицах косинусного расстояния.
    ax.set_xlabel("MDS-1 (единицы косинусного расстояния)")
    ax.set_ylabel("MDS-2 (единицы косинусного расстояния)")
    ax.set_title("Распределение эмбеддингов материалов")
    ax.grid(True, alpha=0.3)
    ax.set_aspect("equal", adjustable="datalim")

    plt.savefig(os.path.join(output_dir, image_name), bbox_inches="tight")
    plt.show()


# ---------------------------------------------------------------------------
# Точка входа
# ---------------------------------------------------------------------------
def main() -> None:
    output_dir: str = get_next_visualization_dir("data")
    print(f"Визуализации будут сохранены в: {output_dir}")
    visualize_graph(embedding_graph, output_dir)
    visualize_embedding_distribution(embedding_graph, output_dir)


if __name__ == "__main__":
    main()
