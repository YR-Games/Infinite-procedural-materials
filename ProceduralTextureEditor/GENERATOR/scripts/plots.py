"""
scripts/plot.py
Модуль для построения графиков и визуализации
"""

import matplotlib.pyplot as plt
import numpy as np
import torch
from sklearn.manifold import TSNE

from .utils import calculate_distance


def plot_training_progress(history: dict[str, list]) -> None:
    """Комплексная визуализация прогресса обучения с метриками"""
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))

    # 1. График потерь
    ax1.plot(history["train_loss"], "b-", label="Потери обучения", linewidth=2)
    ax1.plot(history["test_loss"], "r-", label="Потери теста", linewidth=2)
    ax1.set_title("Динамика Triplet Loss")
    ax1.set_xlabel("Эпоха")
    ax1.set_ylabel("Loss")
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # 2. График точности троек
    accuracies = [metric["triplet_accuracy"] for metric in history["metrics"]]
    ax2.plot(accuracies, "g-", marker="o", label="Triplet Accuracy", linewidth=2)
    ax2.set_title("Triplet Accuracy")
    ax2.set_xlabel("Эпоха")
    ax2.set_ylabel("Accuracy")
    ax2.set_ylim(0, 1)
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    # 3. График расстояний
    pos_dists = [metric["avg_pos_distance"] for metric in history["metrics"]]
    neg_dists = [metric["avg_neg_distance"] for metric in history["metrics"]]
    margins = [metric["avg_margin"] for metric in history["metrics"]]
    ax3.plot(pos_dists, "b-", label="Ср. расстояние до Positive", linewidth=2)
    ax3.plot(neg_dists, "r-", label="Ср. расстояние до Negative", linewidth=2)
    ax3.plot(margins, "g--", label="Ср. margin (Neg - Pos)", linewidth=2)
    ax3.set_title("Динамика расстояний")
    ax3.set_xlabel("Эпоха")
    ax3.set_ylabel("Расстояние")
    ax3.legend()
    ax3.grid(True, alpha=0.3)

    # 4. График соотношения расстояний
    ratios = [metric["distance_ratio"] for metric in history["metrics"]]
    ax4.plot(ratios, "m-", marker="s", label="Neg/Pos Distance Ratio", linewidth=2)
    ax4.set_title("Соотношение расстояний")
    ax4.set_xlabel("Эпоха")
    ax4.set_ylabel("Соотношение")
    ax4.legend()
    ax4.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(
        "data/models/triplet_training_progress.png", dpi=300, bbox_inches="tight"
    )
    plt.close()

    print("\n📊 Сохранена комплексная визуализация прогресса обучения")


def plot_tsne(embeddings, labels, types):
    """t-SNE визуализация эмбеддингов"""
    print("🔄 Выполнение t-SNE...")

    tsne = TSNE(n_components=2, random_state=42, perplexity=30, max_iter=1800)
    embeddings_2d = tsne.fit_transform(embeddings)

    # Создаем subplots
    fig, axes = plt.subplots(1, 2, figsize=(20, 8))

    # 1. Визуализация по классам
    unique_labels = np.unique(labels)
    colors = plt.cm.tab10(np.linspace(0, 1, len(unique_labels)))

    for i, label in enumerate(unique_labels):
        mask = labels == label
        if label == -1:  # Negative samples
            axes[0].scatter(
                embeddings_2d[mask, 0],
                embeddings_2d[mask, 1],
                c="red",
                label="Negative",
                alpha=0.7,
                s=30,
            )
        else:
            axes[0].scatter(
                embeddings_2d[mask, 0],
                embeddings_2d[mask, 1],
                c=[colors[i % len(colors)]],
                label=f"Class {label}",
                alpha=0.7,
                s=30,
            )

    axes[0].set_title("t-SNE: Эмбеддинги по классам")
    axes[0].set_xlabel("t-SNE компонента 1")
    axes[0].set_ylabel("t-SNE компонента 2")
    axes[0].legend(bbox_to_anchor=(1.05, 1), loc="upper left")
    axes[0].grid(True, alpha=0.3)

    # 2. Визуализация по типам (anchor/positive/negative)
    type_colors = {"anchor": "blue", "positive": "green", "negative": "red"}
    for type_name, color in type_colors.items():
        mask = types == type_name
        axes[1].scatter(
            embeddings_2d[mask, 0],
            embeddings_2d[mask, 1],
            c=color,
            label=type_name,
            alpha=0.6,
            s=30,
        )

    axes[1].set_title("t-SNE: Anchor/Positive/Negative")
    axes[1].set_xlabel("t-SNE компонента 1")
    axes[1].set_ylabel("t-SNE компонента 2")
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig("data/models/tsne_visualization.png", dpi=300, bbox_inches="tight")
    plt.show()


def plot_pca(embeddings, labels, types):
    """PCA визуализация эмбеддингов"""
    print("🔄 Выполнение PCA...")

    from sklearn.decomposition import PCA

    pca = PCA(n_components=2, random_state=42)
    embeddings_2d = pca.fit_transform(embeddings)

    fig, axes = plt.subplots(1, 2, figsize=(20, 8))

    # 1. По классам
    unique_labels = np.unique(labels)
    colors = plt.cm.tab10(np.linspace(0, 1, len(unique_labels)))

    for i, label in enumerate(unique_labels):
        mask = labels == label
        if label == -1:  # Negative samples
            axes[0].scatter(
                embeddings_2d[mask, 0],
                embeddings_2d[mask, 1],
                c="red",
                label="Negative",
                alpha=0.7,
                s=30,
            )
        else:
            axes[0].scatter(
                embeddings_2d[mask, 0],
                embeddings_2d[mask, 1],
                c=[colors[i % len(colors)]],
                label=f"Class {label}",
                alpha=0.7,
                s=30,
            )

    axes[0].set_title(
        f"PCA: Эмбеддинги по классам\nОбъясненная дисперсия: {pca.explained_variance_ratio_.sum():.3f}"
    )
    axes[0].set_xlabel(f"PC1 ({pca.explained_variance_ratio_[0]:.3f})")
    axes[0].set_ylabel(f"PC2 ({pca.explained_variance_ratio_[1]:.3f})")
    axes[0].legend(bbox_to_anchor=(1.05, 1), loc="upper left")
    axes[0].grid(True, alpha=0.3)

    # 2. По типам
    type_colors = {"anchor": "blue", "positive": "green", "negative": "red"}
    for type_name, color in type_colors.items():
        mask = types == type_name
        axes[1].scatter(
            embeddings_2d[mask, 0],
            embeddings_2d[mask, 1],
            c=color,
            label=type_name,
            alpha=0.6,
            s=30,
        )

    axes[1].set_title("PCA: Anchor/Positive/Negative")
    axes[1].set_xlabel(f"PC1 ({pca.explained_variance_ratio_[0]:.3f})")
    axes[1].set_ylabel(f"PC2 ({pca.explained_variance_ratio_[1]:.3f})")
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig("data/models/pca_visualization.png", dpi=300, bbox_inches="tight")
    plt.show()


def plot_distance_distribution(model, test_loader, device):
    """Визуализация распределения расстояний"""
    print("📏 Анализ расстояний...")

    model.eval()
    pos_distances = []
    neg_distances = []

    with torch.no_grad():
        for anchor, positive, negative, _ in test_loader:
            anchor, positive, negative = (
                anchor.to(device),
                positive.to(device),
                negative.to(device),
            )

            anchor_emb = model.forward_one(anchor)
            positive_emb = model.forward_one(positive)
            negative_emb = model.forward_one(negative)

            # Вычисляем расстояния
            pos_dist = calculate_distance(anchor_emb, positive_emb).cpu().numpy()
            neg_dist = calculate_distance(anchor_emb, negative_emb).cpu().numpy()

            pos_distances.extend(pos_dist)
            neg_distances.extend(neg_dist)

    # Строим гистограммы
    fig, axes = plt.subplots(1, 2, figsize=(15, 6))

    # Гистограмма расстояний
    axes[0].hist(
        pos_distances,
        bins=50,
        alpha=0.7,
        color="green",
        label="Positive расстояния",
        density=True,
    )
    axes[0].hist(
        neg_distances,
        bins=50,
        alpha=0.7,
        color="red",
        label="Negative расстояния",
        density=True,
    )
    axes[0].set_xlabel("Евклидово расстояние")
    axes[0].set_ylabel("Плотность")
    axes[0].set_title("Распределение расстояний Positive vs Negative")
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)

    # Box plot расстояний
    distance_data = [pos_distances, neg_distances]
    axes[1].boxplot(distance_data, labels=["Positive", "Negative"])
    axes[1].set_ylabel("Евклидово расстояние")
    axes[1].set_title("Box plot расстояний")
    axes[1].grid(True, alpha=0.3)

    # Статистика
    pos_mean, pos_std = np.mean(pos_distances), np.std(pos_distances)
    neg_mean, neg_std = np.mean(neg_distances), np.std(neg_distances)

    axes[1].text(
        0.5,
        0.95,
        f"Positive: {pos_mean:.3f} ± {pos_std:.3f}",
        transform=axes[1].transAxes,
        ha="center",
        color="green",
    )
    axes[1].text(
        0.5,
        0.85,
        f"Negative: {neg_mean:.3f} ± {neg_std:.3f}",
        transform=axes[1].transAxes,
        ha="center",
        color="red",
    )
    axes[1].text(
        0.5,
        0.75,
        f"Ratio: {neg_mean / pos_mean:.3f}",
        transform=axes[1].transAxes,
        ha="center",
        color="blue",
    )

    plt.tight_layout()
    plt.savefig("data/models/distance_analysis.png", dpi=300, bbox_inches="tight")
    plt.show()

    print("📊 Статистика расстояний:")
    print(f"   Positive: {pos_mean:.3f} ± {pos_std:.3f}")
    print(f"   Negative: {neg_mean:.3f} ± {neg_std:.3f}")
    print(f"   Соотношение: {neg_mean / pos_mean:.3f}")
