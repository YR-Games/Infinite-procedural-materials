"""
scripts/train.py
Система дообучения сиамской нейронной сети для определения степени схожести изображений

Входные данные:
    Изображения в директории "data/input/raw".
    Формат изображений:
        Если изображение одно в своём классе - <название класса>.(png/jpg/jpeg)
        Если изображений в классе похожих несколько - <номер класса макропризнаков>_<номер класса микропризнаков>_<название изображения>.(png/jpg/jpeg)
"""

import gc
import json
import os
import signal
from datetime import datetime
from typing import Dict, List, Tuple

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.metrics import f1_score
from torch.optim.lr_scheduler import ReduceLROnPlateau
from torch.utils.data import DataLoader
from tqdm import tqdm

from .config import CONFIG, PATIENCE, STANDARD_DEFINITION, get_config_dict
from .data import DataPrefetcher, create_dataloaders, parse_image_classes
from .logger import train_logger
from .models_manager import get_model_path
from .plots import (
    plot_distance_distribution,
    plot_pca,
    plot_training_progress,
    plot_tsne,
)
from .seamese_network import ModernSiameseNetwork
from .utils import calculate_distance, calculate_similarity


class TripletLoss(nn.Module):
    """Triplet Loss с адаптивным margin и semi-hard mining"""

    def __init__(self, margin: float = 1.0, squared: bool = False):
        super(TripletLoss, self).__init__()
        self.margin = margin
        self.squared = squared

    def forward(
        self, anchors: torch.Tensor, positives: torch.Tensor, negatives: torch.Tensor
    ) -> torch.Tensor:
        """Вычисление Triplet Loss с semi-hard negative mining"""
        if self.squared:
            pos_dist = torch.sum((anchors - positives) ** 2, dim=1)
            neg_dist = torch.sum((anchors - negatives) ** 2, dim=1)
        else:
            pos_dist = calculate_distance(anchors, positives, p=2)
            neg_dist = calculate_distance(anchors, negatives, p=2)

        # Semi-hard negative mining
        if CONFIG.hard_mining:
            # Выбираем только "сложные" тройки
            hard_negatives = neg_dist < pos_dist + self.margin
            if hard_negatives.sum() > 0:
                losses = torch.relu(
                    pos_dist[hard_negatives] - neg_dist[hard_negatives] + self.margin
                )
                return losses.mean()
            else:
                # Если нет сложных троек, возвращаем 0
                return torch.tensor(0.0, device=anchors.device)
        else:
            # Стандартный triplet loss: max(d(anchor, positive) - d(anchor, negative) + margin, 0)
            losses = torch.relu(pos_dist - neg_dist + self.margin)
            return losses.mean()


class Trainer:
    """Класс для управления обучением модели"""

    def __init__(self, data_dir: str, save_path: str):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = self._load_or_create_model()
        self.criterion = TripletLoss(margin=CONFIG.triplet_margin)
        self.optimizer = optim.AdamW(
            self.model.parameters(),
            lr=CONFIG.learning_rate,
            weight_decay=CONFIG.weight_decay,
        )
        self.scheduler = ReduceLROnPlateau(
            self.optimizer, mode="min", patience=5, factor=0.5
        )
        self.scaler = (
            torch.amp.GradScaler(self.device.type)
            if self.device.type == "cuda"
            else None
        )
        self.max_distance = 1.0
        self.threshold = 0.5
        self.best_test_loss = float("inf")
        self.patience_counter = 0
        self.history: Dict[str, List] = {
            "train_loss": [],
            "test_loss": [],
            "metrics": [],
        }

        # Регистрация обработчика прерывания
        self.original_signal = signal.signal(signal.SIGINT, self._signal_handler)

    def _signal_handler(self, sig, frame):
        raise TrainingInterrupt("Обучение прервано пользователем")

    def _load_or_create_model(self) -> ModernSiameseNetwork:
        """Загружает существующую модель или создает новую"""
        model_path = get_model_path()

        model = ModernSiameseNetwork(
            use_pretrained=CONFIG.use_pretrained,
            use_ResNet34_weights=CONFIG.use_ResNet34_weights,
        ).to(self.device)

        if os.path.exists(model_path) and CONFIG.use_pretrained:
            try:
                checkpoint = torch.load(
                    model_path, map_location=self.device, weights_only=False
                )
                model.load_state_dict(checkpoint["model_state_dict"])
                train_logger.info("✅ Загружена существующая модель для дообучения")

                # Восстанавливаем оптимизатор если есть
                if "optimizer_state_dict" in checkpoint:
                    self.optimizer.load_state_dict(checkpoint["optimizer_state_dict"])
                    train_logger.info("✅ Восстановлено состояние оптимизатора")

                # Восстанавливаем другие параметры
                self.max_distance = checkpoint.get("max_distance", self.max_distance)
                self.threshold = checkpoint.get("threshold", self.threshold)

            except Exception as e:
                train_logger.warning(
                    f"⚠️  Ошибка загрузки модели {model_path}: {e}. Создаем новую."
                )
        else:
            if os.path.exists(model_path):
                backup_path = (
                    f"data/models/backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pth"
                )
                os.rename(
                    model_path,
                    backup_path,
                )
                train_logger.info(f"📦 Старая модель перемещена в: {backup_path}")
            train_logger.info("🆕 Создаем новую модель")

        return model

    def _calculate_metrics(
        self, all_pos_distances: List[float], all_neg_distances: List[float]
    ) -> Dict[str, float]:
        """Расчет метрик качества"""
        all_pos_distances = np.array(all_pos_distances)
        all_neg_distances = np.array(all_neg_distances)

        # Accuracy: процент троек, где neg_dist > pos_dist + margin
        correct_triplets = np.sum(
            all_neg_distances > all_pos_distances + CONFIG.triplet_margin
        )
        triplet_accuracy = correct_triplets / len(all_pos_distances)

        # Средние расстояния
        avg_pos_distance = np.mean(all_pos_distances)
        avg_neg_distance = np.mean(all_neg_distances)

        # Distance ratio и margin
        distance_ratio = avg_neg_distance / (avg_pos_distance + 1e-8)
        avg_margin = avg_neg_distance - avg_pos_distance

        return {
            "triplet_accuracy": triplet_accuracy,
            "avg_pos_distance": avg_pos_distance,
            "avg_neg_distance": avg_neg_distance,
            "distance_ratio": distance_ratio,
            "avg_margin": avg_margin,
        }

    def _validate_model(
        self, data_loader: DataLoader
    ) -> Tuple[float, Dict[str, float]]:
        """Валидация модели и расчет метрик"""
        self.model.eval()
        test_loss = 0.0
        all_pos_distances = []
        all_neg_distances = []

        with torch.no_grad():
            for anchor, positive, negative, anchor_labels in data_loader:
                anchor, positive, negative, anchor_labels = (
                    anchor.to(self.device),
                    positive.to(self.device),
                    negative.to(self.device),
                    anchor_labels.to(self.device),
                )

                anchor_emb = self.model.forward_one(anchor)
                positive_emb = self.model.forward_one(positive)
                negative_emb = self.model.forward_one(negative)

                loss = self.criterion(anchor_emb, positive_emb, negative_emb)
                test_loss += loss.item()

                # Собираем расстояния для метрик
                pos_dist = calculate_distance(anchor_emb, positive_emb).cpu().numpy()
                neg_dist = calculate_distance(anchor_emb, negative_emb).cpu().numpy()

                all_pos_distances.extend(pos_dist)
                all_neg_distances.extend(neg_dist)

        avg_test_loss = test_loss / len(data_loader)
        self.max_distance = max(self.max_distance, max(all_neg_distances))
        metrics = self._calculate_metrics(all_pos_distances, all_neg_distances)

        return avg_test_loss, metrics

    def _train_epoch(
        self, data_loader: DataLoader, epoch: int, total_epochs: int
    ) -> float:
        """Обучение модели на одной эпохе"""
        self.model.train()
        train_loss = 0.0
        batch_distances = []

        try:
            prefetcher = DataPrefetcher(data_loader, self.device)
            data = prefetcher.next()

            batch_idx = 0
            progress_bar = tqdm(
                desc=f"Эпоха {epoch + 1}/{total_epochs}", total=len(data_loader)
            )

            while data is not None:
                try:
                    anchor, positive, negative, anchor_labels = data
                    batch_idx += 1

                    self.optimizer.zero_grad(set_to_none=True)

                    if self.scaler:
                        with torch.amp.autocast(self.device.type):
                            anchor_emb = self.model.forward_one(anchor)
                            positive_emb = self.model.forward_one(positive)
                            negative_emb = self.model.forward_one(negative)
                            loss = self.criterion(
                                anchor_emb, positive_emb, negative_emb
                            )
                        self.scaler.scale(loss).backward()
                        self.scaler.unscale_(self.optimizer)
                        torch.nn.utils.clip_grad_norm_(
                            self.model.parameters(), max_norm=1.0
                        )
                        self.scaler.step(self.optimizer)
                        self.scaler.update()
                    else:
                        anchor_emb = self.model.forward_one(anchor)
                        positive_emb = self.model.forward_one(positive)
                        negative_emb = self.model.forward_one(negative)
                        loss = self.criterion(anchor_emb, positive_emb, negative_emb)
                        loss.backward()
                        self.optimizer.step()

                    train_loss += loss.item()

                    # Собираем статистику расстояний
                    with torch.no_grad():
                        pos_dist = calculate_distance(anchor_emb, positive_emb)
                        neg_dist = calculate_distance(anchor_emb, negative_emb)
                        batch_distances.append(
                            {
                                "pos_dist": pos_dist.mean().item(),
                                "neg_dist": neg_dist.mean().item(),
                                "margin": (neg_dist - pos_dist).mean().item(),
                            }
                        )
                        self.max_distance = max(
                            self.max_distance, neg_dist.max().item()
                        )

                    # Обновление прогресс-бара
                    if batch_idx % 10 == 0:
                        current_stats = batch_distances[-1]
                        progress_bar.set_postfix(
                            {
                                "loss": f"{loss.item():.4f}",
                                "pos_dist": f"{current_stats['pos_dist']:.3f}",
                                "neg_dist": f"{current_stats['neg_dist']:.3f}",
                                "margin": f"{current_stats['margin']:.3f}",
                            }
                        )
                    progress_bar.update(1)

                    data = prefetcher.next()

                except TrainingInterrupt:
                    raise
                except Exception as e:
                    train_logger.error(f"Ошибка в батче {batch_idx}: {e}")
                    data = prefetcher.next()
                    continue

            progress_bar.close()

        except TrainingInterrupt:
            raise
        except Exception as e:
            train_logger.error(f"Критическая ошибка в эпохе: {e}")
            raise

        # Статистика по эпохе
        if batch_distances:
            avg_pos_dist = np.mean([d["pos_dist"] for d in batch_distances])
            avg_neg_dist = np.mean([d["neg_dist"] for d in batch_distances])
            avg_margin = np.mean([d["margin"] for d in batch_distances])
            train_logger.info(
                f"   📊 Расстояния: pos={avg_pos_dist:.3f}, neg={avg_neg_dist:.3f}, margin={avg_margin:.3f}"
            )

        return train_loss / batch_idx

    def _apply_optimization_settings(self):
        """Применение оптимизаций производительности"""
        torch.backends.cudnn.benchmark = True
        torch.backends.cuda.matmul.allow_tf32 = True
        torch.backends.cudnn.allow_tf32 = True

        if torch.cuda.is_available():
            device = torch.cuda.current_device()
            torch.cuda.set_device(device)
            torch.cuda.empty_cache()
            torch.cuda.synchronize()
            gc.collect()
            train_logger.info(f"✅ Применены оптимизации CUDA для устройства {device}")

    def _calculate_optimal_threshold(self, test_loader: DataLoader) -> float:
        """Вычисляет оптимальный порог на валидационной выборке с использованием F1-score"""
        self.model.eval()
        distances, labels = [], []

        with torch.no_grad():
            for anchor, positive, negative, _ in test_loader:
                anchor, positive = anchor.to(self.device), positive.to(self.device)
                anchor_emb = self.model.forward_one(anchor)
                positive_emb = self.model.forward_one(positive)

                dist = calculate_distance(anchor_emb, positive_emb)
                distances.extend(dist.cpu().numpy())
                labels.extend([1] * len(dist))  # Positive пары = 1 (похожие)

        np_distances = np.array(distances)

        # Автоматический подбор порога по F1-score
        best_threshold = 0.0
        best_f1 = 0.0

        for threshold in np.linspace(np_distances.min(), np_distances.max(), 100):
            preds = (np_distances < threshold).astype(int)
            f1 = f1_score(labels, preds, zero_division=0)

            if f1 > best_f1:
                best_f1 = f1
                best_threshold = threshold

        train_logger.info(
            f"🎯 Оптимальный порог: {best_threshold:.4f} (F1-score: {best_f1:.4f})"
        )
        return best_threshold

    def _visualize_embeddings(self, test_loader: DataLoader, num_samples: int = 1800):
        """Визуализация эмбеддингов"""
        train_logger.info("🔍 Извлечение эмбеддингов для визуализации...")

        self.model.eval()
        all_embeddings = []
        all_labels = []
        all_types = []

        with torch.no_grad():
            for anchor, positive, negative, anchor_labels in test_loader:
                anchor, positive, negative = (
                    anchor.to(self.device),
                    positive.to(self.device),
                    negative.to(self.device),
                )

                anchor_emb = self.model.forward_one(anchor)
                positive_emb = self.model.forward_one(positive)
                negative_emb = self.model.forward_one(negative)

                batch_size = anchor.size(0)

                all_embeddings.append(anchor_emb.cpu().numpy())
                all_labels.extend(anchor_labels.numpy())
                all_types.extend(["anchor"] * batch_size)

                all_embeddings.append(positive_emb.cpu().numpy())
                all_labels.extend(anchor_labels.numpy())
                all_types.extend(["positive"] * batch_size)

                all_embeddings.append(negative_emb.cpu().numpy())
                all_labels.extend([-1] * batch_size)
                all_types.extend(["negative"] * batch_size)

        embeddings = np.vstack(all_embeddings)
        labels = np.array(all_labels)
        types = np.array(all_types)

        if len(embeddings) > num_samples:
            indices = np.random.choice(len(embeddings), num_samples, replace=False)
            embeddings = embeddings[indices]
            labels = labels[indices]
            types = types[indices]

        train_logger.info(f"📊 Извлечено {len(embeddings)} эмбеддингов")

        plot_tsne(embeddings, labels, types)
        plot_pca(embeddings, labels, types)
        plot_distance_distribution(self.model, test_loader, self.device)

    def train(self):
        """Основная функция обучения"""
        try:
            train_logger.info(
                "\n===================================================================================="
            )
            train_logger.info("🚀 Запуск обучения сиамской сети")
            train_logger.info(f"Используется устройство: {self.device}")

            if CONFIG.use_pretrained:
                train_logger.info("Загрузка ModernSiameseNetwork для дообучения")
            else:
                train_logger.info(
                    "Инициализация ModernSiameseNetwork со случайными весами"
                )

            # Создаем директории
            os.makedirs("data/input/raw", exist_ok=True)
            os.makedirs("data/models", exist_ok=True)
            os.makedirs("logs", exist_ok=True)

            # Парсим изображения
            input_dir = "data/input/raw"
            image_paths, labels = parse_image_classes(input_dir)

            if len(image_paths) == 0:
                train_logger.error(
                    "ОШИБКА: Не найдено изображений для обучения в директории data/input/raw"
                )
                return

            train_loader, test_loader = create_dataloaders(
                image_paths, labels, STANDARD_DEFINITION
            )

            self._apply_optimization_settings()

            total_train_pairs = len(train_loader.dataset)
            total_test_pairs = len(test_loader.dataset)
            total_batches = len(train_loader)

            train_logger.info("📊 Старт обучения сиамской сети")
            train_logger.info(
                f"   📁 Данные: {len(image_paths)} изображений, {len(set(labels))} уникальных классов"
            )
            train_logger.info(f"   🎯 Троек для обучения: {total_train_pairs}")
            train_logger.info(f"   🧪 Троек для тестирования: {total_test_pairs}")
            train_logger.info(f"   🔄 Размер батча: {train_loader.batch_size} троек")
            train_logger.info(f"   📈 Всего батчей в эпохе: {total_batches}")
            train_logger.info(f"   ⏱️  Эпох: {CONFIG.num_epochs}")
            train_logger.info("   🎯 Функция потерь: Triplet Loss")
            train_logger.info(
                f"   ⛏️  Hard mining: {'Включен' if CONFIG.hard_mining else 'Выключен'}"
            )

            if total_batches > 0:
                approx_time_per_epoch = total_batches * train_loader.batch_size * 0.281
                total_time = 1.5 + approx_time_per_epoch * CONFIG.num_epochs / 60
                train_logger.info(f"   🕐 Примерное время: ~{total_time:.1f} минут\n")

            for epoch in range(CONFIG.num_epochs):
                # Фаза обучения
                avg_train_loss = self._train_epoch(
                    train_loader, epoch, CONFIG.num_epochs
                )

                # Валидация
                avg_test_loss, metrics = self._validate_model(test_loader)

                # Логирование
                train_logger.info(
                    f"Эпоха {epoch + 1}/{CONFIG.num_epochs} завершена: "
                    f"Потери обучения: {avg_train_loss:.4f}, "
                    f"Потери теста: {avg_test_loss:.4f}, "
                    f"Средний разброс расстояний: {metrics['avg_margin']:.4f}, "
                    f"Соотношение расстояний: {metrics['distance_ratio']:.4f}, "
                    f"Точность: {metrics['triplet_accuracy']:.4f}\n"
                )

                print(f"📈 Эпоха {epoch + 1} завершена:")
                print(f"   📉 Потери обучения: {avg_train_loss:.4f}")
                print(f"   🧪 Потери теста: {avg_test_loss:.4f}")
                print(
                    f"   ✅ Средний разброс расстояний: {metrics['avg_margin']:.4f} (цель: {CONFIG.triplet_margin})"
                )
                print(f"   📊 Соотношение расстояний: {metrics['distance_ratio']:.4f}")
                print(f"   🎯 Точность: {metrics['triplet_accuracy']:.4f}\n")

                # Сохранение истории
                self.history["train_loss"].append(avg_train_loss)
                self.history["test_loss"].append(avg_test_loss)
                self.history["metrics"].append(metrics)

                # Сохранение лучшей модели
                if avg_test_loss < self.best_test_loss:
                    self.best_test_loss = avg_test_loss
                    self.threshold = self._calculate_optimal_threshold(test_loader)
                    torch.save(
                        {
                            "epoch": epoch,
                            "model_state_dict": self.model.state_dict(),
                            "optimizer_state_dict": self.optimizer.state_dict(),
                            "test_loss": self.best_test_loss,
                            "threshold": self.threshold,
                            "max_distance": self.max_distance,
                            "config": get_config_dict(),
                        },
                        "data/models/best_siamese_model.pth",
                    )
                    train_logger.info("💾 Сохранена новая лучшая модель!\n")
                    self.patience_counter = 0
                else:
                    self.patience_counter += 1
                    if self.patience_counter >= PATIENCE:
                        train_logger.info(
                            "🛑 Обучение преждевременно остановлено, во избежание переобучения!\n"
                        )
                        break

                # Условия для включения Hard Mining
                if not CONFIG.hard_mining and (
                    (epoch < 5 and metrics["triplet_accuracy"] > 0.8)
                    or (
                        epoch > 10
                        and max(self.history["train_loss"][-5:])
                        - min(self.history["train_loss"][-5:])
                        < 0.01
                    )
                    or (
                        epoch > 8
                        and self.history["train_loss"][-1]
                        > self.history["train_loss"][-8] * 0.95
                    )
                ):
                    CONFIG.hard_mining = True
                    self.criterion.margin = 0.8
                    train_logger.info(
                        "⛏️ Включен Hard Mining для сложных примеров, margin уменьшен до 0.8!"
                    )

                self.scheduler.step(avg_test_loss)

            # Сохранение истории
            self.history["train_config"] = get_config_dict()
            with open(
                "data/models/training_history.json",
                "w",
                encoding="utf-8",
            ) as f:
                json.dump(self.history, f, indent=4, ensure_ascii=False, default=str)

            # Визуализация
            plot_training_progress(self.history)
            self._visualize_embeddings(test_loader)

            print("\n🎉 Обучение завершено!")
            print("📁 Результаты сохранены в:")
            print("   - data/models/best_siamese_model.pth (лучшая модель)")
            print("   - data/models/comprehensive_training_progress.png (графики)")
            print("   - logs/ (логи обучения)")

            # Финальное тестирование
            self.model.eval()
            test_predictions = []
            test_labels_list = []

            with torch.no_grad():
                for img1, img2, img3, _ in test_loader:
                    img1, img2, img3 = (
                        img1.to(self.device),
                        img2.to(self.device),
                        img3.to(self.device),
                    )

                    output1, output2 = self.model(img1, img2)
                    output3, output4 = self.model(img1, img3)

                    _, distances1 = calculate_similarity(
                        output1, output2, self.max_distance
                    )
                    _, distances2 = calculate_similarity(
                        output3, output4, self.max_distance
                    )

                    test_predictions.extend(distances1.cpu().numpy())
                    test_predictions.extend(distances2.cpu().numpy())

                    batch_size = img1.size(0)
                    test_labels_list.extend([0] * batch_size)
                    test_labels_list.extend([1] * batch_size)

            correct_predictions = sum(
                (true_label == 0 and distance < self.threshold)
                or (true_label == 1 and distance >= self.threshold)
                for distance, true_label in zip(test_predictions, test_labels_list)
            )
            accuracy = correct_predictions / len(test_predictions)
            print(f"🎯 Финальная точность на тестовой выборке: {accuracy:.4f}")
            print(f"📏 Используемый порог: {self.threshold:.4f}")

        except TrainingInterrupt:
            train_logger.info(
                "🛑 Обучение прервано пользователем, сохранение чекпоинта..."
            )

            checkpoint_path = "data/models/interrupted_checkpoint.pth"
            # ??? Добавить загрузку прерванных сохрранений для прожолжения!
            torch.save(
                {
                    "epoch": epoch,
                    "model_state_dict": self.model.state_dict(),
                    "optimizer_state_dict": self.optimizer.state_dict(),
                    "scheduler_state_dict": self.scheduler.state_dict(),
                    "test_loss": self.best_test_loss,
                    "threshold": self.threshold,
                    "max_distance": self.max_distance,
                    "history": self.history,
                },
                checkpoint_path,
            )

            train_logger.info(f"💾 Чекпоинт сохранен: {checkpoint_path}")

        except Exception as e:
            train_logger.error(f"💥 Критическая ошибка обучения: {e}")
            raise

        finally:
            signal.signal(signal.SIGINT, self.original_signal)
            train_logger.info(
                "\n====================================================================================\n\n"
            )


class TrainingInterrupt(Exception):
    pass


if __name__ == "__main__":
    trainer = Trainer()
    trainer.train()
