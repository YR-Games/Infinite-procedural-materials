# pyright: reportUnknownMemberType=false
# reportUnknownMemberType отключён для этого файла, потому что стабы matplotlib
# объявляют **kwargs: Unknown, из-за чего каждый вызов plt.* и ax.* даёт эту
# диагностику. См. https://github.com/microsoft/pyright/issues/2923

"""
scripts/visualization.py
Визуализирует:
    1. Внутреннюю структуру графа эмбеддингов (в двух вариантах: честные
       расстояния и читаемая версия с искусственно раздвинутыми кругами);
    2. Распределение эмбеддингов материалов в пространстве: изображение с точками
       в двумерном пространстве расстояний, подписанными номерами, и файлы
       с RenderNode.material_params, названные соответствующими номерами, все точки
       одного RenderNode.material_id покрашены в один цвет, изображение сопровождается
       легендой и масштабом.
"""

import os
import sys
from typing import Any

import matplotlib.patheffects as pe
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
from matplotlib.lines import Line2D
from matplotlib.patches import Wedge
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


def _flat_vector(vec: np.ndarray) -> np.ndarray:
    """
    Приводит вектор эмбеддинга/центроида к плоской форме ``(d,)``.

    В ``embedding_graph`` эмбеддинги хранятся в форме ``(1, d)``
    (см. ``AbstractGraph._get_norm_embedding``), но визуализация
    ожидает классическую форму ``(d,)`` для матричных операций.
    ``ravel`` работает в обоих случаях.
    """
    return vec.ravel()


def _separate_overlaps(
    pos_arr: np.ndarray,
    radii: np.ndarray,
    gap: float,
    iterations: int = 200,
) -> np.ndarray:
    """
    Итеративно раздвигает круги, пока их радиусы не перестанут
    пересекаться. Каждая итерация разрешает половину наложения в
    каждой паре — этого достаточно для сходимости на типичных
    размерах кластеров.

    :param pos_arr: (n, 2) — координаты центров.
    :param radii: (n,) — радиусы.
    :param gap: минимальный зазор между кругами.
    :return: новые координаты (n, 2).
    """
    pos_arr = pos_arr.copy()
    n: int = len(pos_arr)
    if n < 2:
        return pos_arr

    for _ in range(iterations):
        moved: bool = False
        for i in range(n):
            for j in range(i + 1, n):
                diff: np.ndarray = pos_arr[j] - pos_arr[i]
                d: float = float(np.linalg.norm(diff))
                if d < 1e-12:
                    # Совпадающие точки: разводим по произвольному
                    # направлению, чтобы не делить на ноль.
                    direction = np.array([1.0, 0.0])
                    pos_arr[j] += direction * (radii[i] + radii[j] + gap) * 0.5
                    moved = True
                    continue
                min_d: float = radii[i] + radii[j] + gap
                if d < min_d:
                    unit: np.ndarray = diff / d
                    push: float = (min_d - d) * 0.5
                    pos_arr[i] -= unit * push
                    pos_arr[j] += unit * push
                    moved = True
        if not moved:
            break
    return pos_arr


# ---------------------------------------------------------------------------
# 1. Внутренняя структура графа эмбеддингов
# ---------------------------------------------------------------------------
def visualize_graph(
    graph: AbstractGraph,
    output_dir: str,
    sim_threshold: float = 0.7,
    separate_overlaps: bool = True,
    image_name: str = "graph_structure.png",
) -> None:
    """
    Визуализирует внутреннюю структуру графа эмбеддингов.

    Каждый узел — кластер, нарисованный как круговая диаграмма:
    количество равных секторов равно числу RenderNode в кластере,
    цвет сектора — цвет ``material_id`` соответствующего RenderNode.
    В центре узла — число RenderNode в кластере. Между кластерами,
    косинусное сходство центроидов которых не меньше
    ``sim_threshold``, добавляются рёбра. Результат сохраняется в
    ``<output_dir>/<image_name>``.

    :param separate_overlaps: если ``True``, круги раздвигаются
        итеративным отталкиванием (читаемая версия, но взаимные
        расстояния кластеров перестают отражать реальное сходство
        — об этом предупреждает заголовок). Если ``False``, круги
        остаются на позициях ``spring_layout`` — картина честная,
        но соседние кластеры могут сильно наслаиваться.
    :param image_name: имя выходного файла внутри ``output_dir``.
    """
    G: nx.Graph[int, dict[str, Any], dict[str, Any]] = nx.Graph()

    cid: int
    cluster: ClusterNode
    for cid, cluster in graph.clusters.items():
        if cluster.size == 0:
            continue
        G.add_node(cid, size=cluster.size)

    ids: list[int] = list(G.nodes)
    if len(ids) > 1:
        centroids: np.ndarray = np.array(
            [_flat_vector(graph.clusters[c].centroid) for c in ids],
            dtype=np.float32,
        )
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

    # Единая палитра material_id -> цвет (та же, что в
    # visualize_embedding_distribution).
    all_nodes: list[RenderNode] = _collect_render_nodes(graph)
    unique_mids: list[int] = list(dict.fromkeys(n.material_id for n in all_nodes))
    cmap = plt.get_cmap("tab20")
    mid_colors: dict[int, tuple[float, float, float, float]] = {
        mid: cmap(i % 20) for i, mid in enumerate(unique_mids)
    }

    # Первичное размещение: spring_layout с увеличенным k, чтобы
    # изначально разнести узлы сильнее, чем по умолчанию.
    pos: dict[int, np.ndarray] = nx.spring_layout(
        G, seed=42, weight="weight", k=2.0, iterations=300
    )

    node_ids: list[int] = list(G.nodes)
    pos_arr: np.ndarray = np.array([pos[cid] for cid in node_ids], dtype=np.float64)

    span0: float = max(
        float(pos_arr[:, 0].max() - pos_arr[:, 0].min()),
        float(pos_arr[:, 1].max() - pos_arr[:, 1].min()),
    )
    if span0 < 1e-3:
        span0 = 1.0

    max_cluster_size: int = max((graph.clusters[c].size for c in node_ids), default=1)
    max_radius: float = 0.035 * span0
    radii: np.ndarray = np.array(
        [
            max_radius * (graph.clusters[cid].size / max_cluster_size) ** 0.5
            for cid in node_ids
        ],
        dtype=np.float64,
    )

    # Раздвигаем круги только в «читаемой» версии. В честной версии
    # позиции остаются ровно такими, какими их построил spring_layout —
    # с наложениями, но с настоящими взаимными расстояниями.
    if separate_overlaps:
        gap: float = 0.01 * span0
        pos_arr = _separate_overlaps(pos_arr, radii, gap, iterations=200)

    for idx, cid in enumerate(node_ids):
        pos[cid] = pos_arr[idx]

    xs: list[float] = [float(p[0]) for p in pos.values()]
    ys: list[float] = [float(p[1]) for p in pos.values()]

    # Размер фигуры растёт с числом кластеров — детали не сливаются.
    side: float = max(14.0, min(32.0, 10.0 + 0.3 * len(node_ids)))
    _, ax = plt.subplots(figsize=(side, side))
    nx.draw_networkx_edges(G, pos, ax=ax, edge_color="gray", width=1.0)

    idx: int
    for idx, cid in enumerate(node_ids):
        cluster = graph.clusters[cid]
        r: float = float(radii[idx])
        x: float = float(pos_arr[idx, 0])
        y: float = float(pos_arr[idx, 1])

        # Один равный сектор на каждый RenderNode; сортируем по
        # material_id, чтобы одноцветные сектора шли подряд.
        sorted_nodes: list[RenderNode] = sorted(
            cluster.nodes, key=lambda n: n.material_id
        )
        n_sec: int = len(sorted_nodes)
        if n_sec == 0:
            continue

        k: int
        node: RenderNode
        for k, node in enumerate(sorted_nodes):
            theta1: float = 90.0 + k * 360.0 / n_sec
            theta2: float = 90.0 + (k + 1) * 360.0 / n_sec
            wedge = Wedge(
                (x, y),
                r,
                theta1,
                theta2,
                facecolor=mid_colors[node.material_id],
                edgecolor="black",
                linewidth=0.5,
            )
            ax.add_patch(wedge)

        # Число RenderNode в кластере — в центре круга.
        # Шрифт крупнее, вокруг глифов — тонкая белая обводка, чтобы
        # цифра читалась на любом цвете сектора.
        font_size: float = max(10.0, min(22.0, 22.0 * r / max_radius))
        ax.text(
            x,
            y,
            str(cluster.size),
            fontsize=font_size,
            ha="center",
            va="center",
            zorder=5,
            fontweight="bold",
            path_effects=[pe.withStroke(linewidth=1.2, foreground="white")],
        )

    # Запас, чтобы «пироги» не обрезались по краям.
    margin: float = max_radius * 1.6
    ax.set_xlim(min(xs) - margin, max(xs) + margin)
    ax.set_ylim(min(ys) - margin, max(ys) + margin)
    ax.set_aspect("equal")
    ax.axis("off")

    # Легенда: одна запись на каждый material_id, отсортированы
    # по возрастанию, размещены справа от области данных.
    if mid_colors:
        sorted_mids: list[int] = sorted(mid_colors.keys())
        handles: list[Line2D] = [
            Line2D(
                [0],
                [0],
                marker="o",
                color="w",
                markerfacecolor=mid_colors[mid],
                markersize=10,
                label=str(mid),
            )
            for mid in sorted_mids
        ]
        ax.legend(
            handles=handles,
            loc="upper left",
            bbox_to_anchor=(1.02, 1.0),
            fontsize=8,
            title="material_id",
            framealpha=0.9,
            borderaxespad=0.0,
        )

    # Заголовок: в читаемой версии — предупреждение, что расстояния
    # искусственно увеличены.
    if separate_overlaps:
        plt.title(
            "Внутренняя структура графа эмбеддингов\n"
            "ВНИМАНИЕ: круги раздвинуты для читаемости — "
            "взаимные расстояния НЕ соответствуют реальному сходству"
        )
    else:
        plt.title(
            "Внутренняя структура графа эмбеддингов\n(честные расстояния spring_layout)"
        )

    output_path: str = os.path.join(output_dir, image_name)
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
    цвет. Легенда отсортирована по ``(material_id, ordinal)`` и
    размещена под областью данных в несколько колонок, чтобы не
    перекрывать точки.
    """
    os.makedirs(output_dir, exist_ok=True)

    nodes: list[RenderNode] = _collect_render_nodes(graph)
    if not nodes:
        print("Нет RenderNode — визуализация невозможна.")
        return

    # Формируем метки <material_id>_<ordinal>.
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

    # Эмбеддинги уже нормализованы в embedding_graph — только
    # укладываем их в матрицу (n, d), разворачивая форму (1, d).
    embeddings: np.ndarray = np.array(
        [_flat_vector(n.embedding) for n in nodes], dtype=np.float32
    )

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

    # Текстовые файлы <material_id>_<ordinal>.txt.
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
            s=150,
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
            path_effects=[pe.withStroke(linewidth=1.5, foreground="white")]
        )

    # Легенда: сортируем по (material_id, ordinal) и размещаем
    # под областью данных; ncol подбираем так, чтобы список не был
    # чрезмерно длинным.
    sorted_indices: list[int] = sorted(
        range(len(labels)),
        key=lambda i: (material_ids[i], int(labels[i].split("_")[1])),
    )
    handles: list[Line2D] = []
    for i in sorted_indices:
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

    n_handles: int = len(handles)
    ncol: int = max(1, min(10, (n_handles + 9) // 10))
    ax.legend(
        handles=handles,
        loc="upper center",
        bbox_to_anchor=(0.5, -0.06),
        fontsize=7,
        title="<material_id>_<ordinal>",
        framealpha=0.9,
        ncol=ncol,
        borderaxespad=0.0,
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

    # 1а. Честные расстояния: круги на позициях spring_layout,
    #     без искусственного раздвижения (возможны наложения).
    visualize_graph(
        embedding_graph,
        output_dir,
        separate_overlaps=False,
        image_name="graph_structure.png",
    )

    # 1б. Читаемая версия: круги раздвинуты — расстояния не настоящие.
    visualize_graph(
        embedding_graph,
        output_dir,
        separate_overlaps=True,
        image_name="graph_structure_readable.png",
    )

    # 2. Распределение эмбеддингов.
    visualize_embedding_distribution(embedding_graph, output_dir)


if __name__ == "__main__":
    main()
