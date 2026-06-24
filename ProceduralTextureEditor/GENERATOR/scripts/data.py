"""
scripts/data.py
Модуль для работы с выборками и даталоэдерами
"""

import os
import re
from typing import Dict, List, Optional, Tuple

import numpy as np
import torch
import torchvision.transforms as transforms
from PIL import Image
from sklearn.model_selection import train_test_split
from torch.utils.data import DataLoader, Dataset
from torchvision.transforms import ToPILImage
from tqdm import tqdm

from .config import DL_CONFIG, TEST_TRIPLETS_PER_IMAGE_CLASS, TRIPLETS_PER_IMAGE_CLASS
from .utils import bilateral_filter, get_base_transform, inscribed_square_crop


class CustomImageDataset(Dataset):  # type: ignore
    """Датасет для пользовательских изображений с метками классов"""

    def __init__(self, image_paths: List[str], labels: List[int]) -> None:
        self.image_paths: List[str] = image_paths
        self.labels: List[int] = labels
        self.unique_labels: List[int] = list(set(labels))

    def __len__(self) -> int:
        return len(self.image_paths)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, int]:
        img_path: str = self.image_paths[idx]
        with Image.open(img_path) as img:
            image = img.convert("L")  # Конвертируем в grayscale
        label: int = self.labels[idx]

        return image, label


class TripletDataset(Dataset):
    """Датасет для троек изображений (anchor, positive, negative)"""

    def __init__(
        self,
        dataset: CustomImageDataset,
        transform: Optional[transforms.Compose] = None,
        triplets_per_class: int = TRIPLETS_PER_IMAGE_CLASS,
        weak_augmentation: Optional[transforms.Compose] = None,
    ):
        self.dataset: CustomImageDataset = dataset
        self.transform: Optional[transforms.Compose] = transform
        self.weak_augmentation: Optional[transforms.Compose] = weak_augmentation
        self.triplets_per_class: int = triplets_per_class
        self.self_pair_flags: List[bool] = []
        self.triplets: List[Tuple[int, int, int]] = self._create_triplets()

    def _create_triplets(self) -> List[Tuple[int, int, int]]:
        """Создание троек (anchor, positive, negative)"""
        # Группируем индексы по классам
        class_indices: Dict[int, List[int]] = {}
        for idx, (_, label) in enumerate(self.dataset):
            if label not in class_indices:
                class_indices[label] = []
            class_indices[label].append(idx)

        triplets = []
        class_list = list(class_indices.keys())

        print(f"\nСоздание троек для {len(class_list)} классов...")

        for class_idx in class_list:
            indices: list[int] = class_indices[class_idx]
            other_classes: list[int] = [c for c in class_list if c != class_idx]
            self_pair: int = 0
            class_pair: int = 0

            for _ in range(self.triplets_per_class):
                # Anchor и Positive из одного класса
                anchor_idx: int = np.random.choice(indices)
                positive_idx: int = anchor_idx
                if (
                    len(indices) == 1 or np.random.random() > 0.6
                ):  # 50-100% пар с самим собой, к которым будут применены сильные аугментации
                    self.self_pair_flags.append(True)
                    self_pair += 1
                else:  # 50% с изображениями своего класса, со слабыми аугментациями
                    # Убедимся, что positive отличается от anchor
                    while positive_idx == anchor_idx:
                        positive_idx = np.random.choice(indices)
                    self.self_pair_flags.append(False)
                    class_pair += 1

                # Negative из другого класса
                negative_class = np.random.choice(other_classes)
                negative_idx = np.random.choice(class_indices[negative_class])

                triplets.append((anchor_idx, positive_idx, negative_idx))

            print(
                f"Класс {class_idx} ({len(indices)} изображений): "
                f"создано {self_pair} пар с собой, "
                f"{class_pair} пар внутри класса, "
                f"{self_pair + class_pair} пар с другими классами"
            )

        print(f"Создано {len(triplets)} троек\n")
        return triplets

    def __len__(self) -> int:
        return len(self.triplets)

    def __getitem__(
        self, idx: int
    ) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor, torch.Tensor]:
        """Создаёт агрессивно аугментированные тройки, если похожие - одно изображение,
        иначе все три изображения получают мягкие аугментации, а также возвращает метки."""
        anchor_idx, positive_idx, negative_idx = self.triplets[idx]

        anchor_img, anchor_label = self.dataset[anchor_idx]
        positive_img, _ = self.dataset[positive_idx]
        negative_img, _ = self.dataset[negative_idx]

        # Применяем трансформации если есть
        if self.transform:
            # Если доступны слабые аугментации И похожие - это разные изображения
            if self.weak_augmentation and not self.self_pair_flags[idx]:
                transform_to_use = self.weak_augmentation
            else:
                transform_to_use = self.transform

            if isinstance(anchor_img, torch.Tensor):
                anchor_img = transform_to_use(transforms.ToPILImage()(anchor_img))
                positive_img = transform_to_use(transforms.ToPILImage()(positive_img))
                negative_img = transform_to_use(transforms.ToPILImage()(negative_img))
            else:
                anchor_img = transform_to_use(anchor_img)
                positive_img = transform_to_use(positive_img)
                negative_img = transform_to_use(negative_img)

        # self.write_to_file([anchor_img, positive_img, negative_img], idx, self.weak_augmentation) #??? сохраняет изображения после трансформаций в файл

        return (
            anchor_img,
            positive_img,
            negative_img,
            torch.tensor(anchor_label, dtype=torch.long),
        )

    @staticmethod
    def write_to_file(
        imgs: list[torch.Tensor], triplet_id: int, train: bool = True
    ) -> None:
        """Сохраняет изображение в файл"""
        for i in range(len(imgs)):
            path: str = f"data/input/dataset/{'train' if train else 'test'}/pair-{triplet_id}_lable-{i}.png"
            os.makedirs(os.path.dirname(path), exist_ok=True)
            to_pil = ToPILImage()
            img = imgs[i] * 0.5 + 0.5
            """if pair_id % 111 == 0:  # Визуализация изображений
                plt.imshow(img.permute(1, 2, 0))  # CHW → HWC
                plt.show()"""
            pil_img = to_pil(img)
            pil_img.save(path)


class DataPrefetcher:
    """
    Модуль асинхронной предзагрузки данных
    """

    def __init__(self, loader, device):
        self.loader = iter(loader)
        self.device = device
        self.stream = torch.cuda.Stream() if device.type == "cuda" else None
        self.preload()

    def preload(self):
        try:
            self.next_data = next(self.loader)
        except StopIteration:
            self.next_data = None
            return

        if self.stream is not None:
            with torch.cuda.stream(self.stream):
                self.next_data = [
                    d.to(self.device, non_blocking=True) if torch.is_tensor(d) else d
                    for d in self.next_data
                ]
        else:
            self.next_data = [
                d.to(self.device) if torch.is_tensor(d) else d for d in self.next_data
            ]

    def next(self):
        if self.stream is not None:
            torch.cuda.current_stream().wait_stream(self.stream)
        data = self.next_data
        if data is not None:
            self.preload()
        return data


def validate_image_files(
    image_paths: List[str], labels: List[int]
) -> Tuple[List[str], List[int]]:
    """Проверяет целостность изображений"""
    valid_paths = []
    valid_labels = []
    corrupted_count = 0

    for i, path in enumerate(tqdm(image_paths, desc="Валидация изображений")):
        try:
            # Базовая проверка существования файла
            if not os.path.exists(path):
                print(f"⚠️ Файл не найден: {path}")
                corrupted_count += 1
                continue

            # Попытка открыть изображение
            with Image.open(path) as img:
                img.verify()  # Базовая проверка целостности

            valid_paths.append(path)
            valid_labels.append(labels[i])

        except Exception as e:
            print(f"⚠️ Повреждённый файл {path}: {e}")
            corrupted_count += 1

    print(
        f"📊 Валидация завершена: {len(valid_paths)}/{len(image_paths)} валидных, "
        f"{corrupted_count} поврежденных"
    )

    if len(valid_paths) == 0:
        raise ValueError("❌ Не найдено ни одного валидного изображения!")

    return valid_paths, valid_labels


def parse_image_classes(
    input_dir: str, macro: bool = True
) -> Tuple[List[str], List[int]]:
    """Парсит изображения и определяет классы на основе имен файлов"""
    image_paths: List[str] = []
    labels: List[int] = []

    for filename in os.listdir(input_dir):
        if filename.lower().endswith((".png", ".jpg", ".jpeg")):
            filepath: str = os.path.join(input_dir, filename)

            # Извлекаем числа из имени файла по шаблону "<число>_<число>_"
            match = re.match(r"^(\d+)_(\d+)_", filename)
            if match:
                if macro:
                    class_id: int = int(match.group(1))  # Первое число
                else:
                    class_id: int = int(match.group(2))  # Второе число
            else:
                # Если шаблон не найден, используем хэш имени файла как уникальный класс
                class_id = hash(filename) % 1000000  # Ограничиваем размер хэша

            image_paths.append(filepath)
            labels.append(class_id)

    image_paths, labels = validate_image_files(image_paths, labels)

    return image_paths, labels


def optimize_dataloader_config():
    """Автоматическая оптимизация конфигурации DataLoader"""
    import multiprocessing

    cpu_cores = multiprocessing.cpu_count()

    if torch.cuda.is_available():
        gpu_memory = torch.cuda.get_device_properties(0).total_memory / 1e9  # GB

        # Эмпирические правила
        num_workers = max(cpu_cores // 2, 1)  # Не более 8 воркеров при 16 ядрах
        batch_size_base = int(
            gpu_memory * 3
        )  # Эмпирическая формула (5.1 если больше 24 Гб видеопамяти)

        config = {
            "batch_size": min(
                batch_size_base, 128
            ),  # Максимум 128, влияет на качество обучения, многократно увеличивает потребление видео и оперативной памяти!
            "num_workers": num_workers,  # Определяет скорость подготовки данных
            "prefetch_factor": 2,
            "pin_memory": True,
        }

        print("🤖 Автонастройка DataLoader:")
        print(f"   CPU ядер: {cpu_cores}")
        print(f"   GPU память: {gpu_memory:.1f} GB")
        print(f"   Batch size: {config['batch_size']}")
        print(f"   Workers: {config['num_workers']}")

        return config
    else:
        return {"batch_size": 16, "num_workers": 4, "pin_memory": False}


def create_dataloaders(
    image_paths: List[str],
    labels: List[int],
    standard_definition: int,
    macro: bool = True,
) -> Tuple[DataLoader, DataLoader]:
    """
    Создает тренировочный и тестовый (триплет) DataLoader'ы для сеамской сети.

    Args:
        image_paths: Список путей к изображениям
        labels: Список меток классов
        standard_definition: Стандартный размер изображения

    Returns:
        Tuple[DataLoader, DataLoader]: (train_loader, test_loader)
    """
    # Базовые трансформации (применяются к тестовым изображениям)
    base_transform = get_base_transform()

    if macro:  # Для определения макропризнаков добавляем размытие мелких деталей с сохранением границ
        # Трансформации для аугментации (только для обучения)
        augmentation_transform = transforms.Compose(
            [
                transforms.RandomAffine(
                    degrees=360, translate=(0.02, 0.02), scale=(0.8, 1.2)
                ),
                transforms.RandomPerspective(
                    distortion_scale=0.2, p=0.2
                ),  # Добавляет перспективу ± 20%
                transforms.Lambda(
                    inscribed_square_crop
                ),  # Автоматически определяем размер вписанного квадрата
                transforms.Resize((standard_definition, standard_definition)),
                transforms.Lambda(bilateral_filter),  # Размытие мелких деталей
                transforms.ColorJitter(
                    contrast=0.2,  # Контрастность ±20%
                    brightness=0.05,  # Яркость ±5% (опционально)
                    saturation=0.1,  # Насыщенность ±10% (опционально)
                    hue=0.1,  # Оттенок ±10% (опционально)
                ),
                transforms.RandomAdjustSharpness(sharpness_factor=2, p=0.3),
                transforms.ToTensor(),
                transforms.Normalize((0.5), (0.5)),
            ]
        )

        # Для троек, где похожие - "разные изображения одного класса" - СЛАБЫЕ аугментации
        weak_augmentation = transforms.Compose(
            [
                transforms.RandomAffine(
                    degrees=20, translate=(0.01, 0.01)
                ),  # Слабые изменения
                transforms.Lambda(
                    inscribed_square_crop
                ),  # Автоматически определяем размер вписанного квадрата
                transforms.Resize((standard_definition, standard_definition)),
                transforms.Lambda(bilateral_filter),  # Размытие мелких деталей
                transforms.ColorJitter(contrast=0.1, brightness=0.05),
                transforms.ToTensor(),
                transforms.Normalize((0.5), (0.5)),
            ]
        )
    else:
        # Трансформации для аугментации (только для обучения)
        augmentation_transform = transforms.Compose(
            [
                transforms.RandomAffine(
                    degrees=360, translate=(0.02, 0.02), scale=(0.8, 1.2)
                ),
                transforms.RandomPerspective(
                    distortion_scale=0.2, p=0.2
                ),  # Добавляет перспективу ± 20%
                transforms.Lambda(
                    inscribed_square_crop
                ),  # Автоматически определяем размер вписанного квадрата
                transforms.Resize((standard_definition, standard_definition)),
                transforms.ColorJitter(
                    contrast=0.2,  # Контрастность ±20%
                    brightness=0.05,  # Яркость ±5% (опционально)
                    saturation=0.1,  # Насыщенность ±10% (опционально)
                    hue=0.1,  # Оттенок ±10% (опционально)
                ),
                transforms.RandomAdjustSharpness(sharpness_factor=2, p=0.3),
                transforms.ToTensor(),
                transforms.Normalize((0.5), (0.5)),
            ]
        )

        # Для троек, где похожие - "разные изображения одного класса" - СЛАБЫЕ аугментации
        weak_augmentation = transforms.Compose(
            [
                transforms.RandomAffine(
                    degrees=20, translate=(0.01, 0.01)
                ),  # Слабые изменения
                transforms.Lambda(
                    inscribed_square_crop
                ),  # Автоматически определяем размер вписанного квадрата
                transforms.Resize((standard_definition, standard_definition)),
                transforms.ColorJitter(contrast=0.1, brightness=0.05),
                transforms.ToTensor(),
                transforms.Normalize((0.5), (0.5)),
            ]
        )

    # Разделяем на train/test
    train_paths, test_paths, train_labels, test_labels = train_test_split(
        image_paths, labels, test_size=0.2, random_state=8
    )

    # Создаем датасеты
    train_dataset = CustomImageDataset(train_paths, train_labels)
    test_dataset = CustomImageDataset(test_paths, test_labels)

    triplet_train_dataset = TripletDataset(
        train_dataset,
        transform=augmentation_transform,
        weak_augmentation=weak_augmentation,
        triplets_per_class=TRIPLETS_PER_IMAGE_CLASS,  # Меньше чем пар, так как каждая тройка информативнее
    )

    triplet_test_dataset = TripletDataset(
        test_dataset,
        transform=base_transform,
        triplets_per_class=TEST_TRIPLETS_PER_IMAGE_CLASS,
    )

    # Оптимизируем конфигурацию DataLoader'а
    DL_CONFIG.update(optimize_dataloader_config())

    # Создаем DataLoader'ы
    train_loader = DataLoader(
        triplet_train_dataset,
        batch_size=DL_CONFIG["batch_size"],
        shuffle=True,
        num_workers=DL_CONFIG["num_workers"],
        pin_memory=DL_CONFIG["pin_memory"],
        persistent_workers=DL_CONFIG["num_workers"] > 0,
        prefetch_factor=DL_CONFIG.get("prefetch_factor", 2),
    )

    test_loader = DataLoader(
        triplet_test_dataset,
        batch_size=DL_CONFIG["batch_size"],
        shuffle=False,
        num_workers=DL_CONFIG["num_workers"],
        pin_memory=DL_CONFIG["pin_memory"],
        persistent_workers=DL_CONFIG["num_workers"] > 0,
    )

    print(f"\n🗂️  Размер батча: {DL_CONFIG['batch_size']}")
    print(f" Троек для обучения: {len(triplet_train_dataset)}")
    print(f" Троек для теста: {len(triplet_test_dataset)}\n")

    return train_loader, test_loader
