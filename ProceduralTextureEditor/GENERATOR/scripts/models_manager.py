"""
scripts/models_manager.py
Управление моделями.
Автоматически ищет модели в папке библиотеки. Если не найдены, копирует свежие версии из data/models.
Возвращает загруженные модели.
"""

import base64
from functools import lru_cache
from io import BytesIO

import torch
import torch.nn as nn
from PIL import Image
from transformers import AutoImageProcessor, AutoModel

from .config import STANDARD_DEFINITION
from .logger import lib_logger
from .utils import get_base_transform

# Конфигурация.
device: str = "cuda" if torch.cuda.is_available() else "cpu"
"""Используемое устройство."""
threshold: float = 0.15
"""Порог уверенности для формирования кластера."""

model_name = "facebook/dinov2-base"  # Доступные размеры модели: dinov2-small (384), base (768), large (1024) - в скобках размерность выходного вектора


# Загружаем процессор и модель.
processor = AutoImageProcessor.from_pretrained(model_name)  # type: ignore
_embedding_model: nn.Module = AutoModel.from_pretrained(model_name).to(device)  # type: ignore
_embedding_model.eval()  # type: ignore # Переводим модель в режим "оценки"


@lru_cache(maxsize=1000)
def base64_to_pil(data: str) -> Image.Image:
    image_bytes = base64.b64decode(data)
    return Image.open(BytesIO(image_bytes)).convert("RGB")


@lru_cache(maxsize=1000)
def get_embedding(image: str) -> torch.Tensor:  # numpy.ndarray
    """
    Пропускает изображение через модель и возвращает эмбеддинг.

    Args:
        image_path: путь к изображению

    Returns:
        torch.Tensor: ембеддинг
    """
    try:
        # Получаем эмбеддинг.
        with torch.no_grad():
            outputs = _embedding_model(load_and_transform_image(image))

        # Извлекаем эмбеддинг [CLS] токена (используется как представление всего изображения).
        embedding: torch.Tensor = outputs.last_hidden_state[:, 0, :].cpu()
        return embedding
    except Exception as e:
        lib_logger.error(
            f"Ошибка получения эмбеддинга для изображения '{image[:100]}': {e}"
        )
        raise


@lru_cache(maxsize=1000)
def load_and_transform_image(
    image: str, definition: int = STANDARD_DEFINITION, to_device: bool = True
) -> torch.Tensor:
    """Загрузка и трансформация изображения с кэшированием"""
    # if not os.path.exists(image_path):
    #    raise FileNotFoundError(f"Image not found: {image_path}")

    transform = get_base_transform(definition)
    img = base64_to_pil(image)  # Image.open(image_path).convert("RGB")

    """# Визуализация изображений ???
    import matplotlib.pyplot as plt

    img1 = transform(img) * 0.5 + 0.5
    plt.imshow(img1.permute(1, 2, 0))  # CHW → HWC
    plt.show()"""
    transformed = transform(img)
    return transformed.unsqueeze(0).to(device) if to_device else transformed


# =========================================================================
"""
_model_path: str = "best_siamese_model.pth"
'''Базовые общедоступные параметры.'''
device: str = "cuda" if torch.cuda.is_available() else "cpu"
'''Используемое устройство.'''
max_distance: float = 2.0
'''Максимальное значение ответа (??? заменить на косинусное расстояние, что бы стало лишним!).'''

# Установака стандартных директорий моделей.
models_dir = os.path.join(main_dir, "data", "models")
if not os.path.exists(models_dir):
    os.makedirs(models_dir)
print("Директория моделей: ", models_dir)  # ???

# similarity_model = _load_similarity_model(source_models_dir, models_dir)
_embedding_model: SiameseNetwork | None = None
'''Модель для получения эмбеддингов.'''


def get_model_path() -> str:
    return _model_path


def set_model_path(model_path: str):
    global _model_path
    _model_path = model_path

def _load_model() -> SiameseNetwork:
    # ??? Переделать на использование стандартной модели без поледнего слоя!
    '''Загрузка модели с обработкой ошибок'''
    global _model_path, threshold, max_distance, models_dir
    path: str = os.path.join(models_dir, _model_path)
    if not os.path.exists(path):
        lib_logger.warning(f"Model not found at {path}")
        path = "data/models/best_siamese_model.pth"
        if not os.path.exists(path):
            raise FileNotFoundError("Модель не найдена ни по какому пути😫")

    # Загрузка чекпоинта с безопасными глобалами
    checkpoint = torch.load(path, map_location=device, weights_only=False)
    threshold = checkpoint.get("threshold", threshold)
    max_distance = max(max_distance, checkpoint.get("max_distance", max_distance))

    model = SiameseNetwork(use_pretrained=False).to(device)
    #ModernSiameseNetwork(
    #    use_ResNet34_weights=False,  # Не загружаем ImageNet веса, т.к. свои уже есть
    #    use_pretrained=False  # Не загружаем ImageNet веса, т.к. свои уже есть
    #).to(self.device)

    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    lib_logger.info(f"Модель успешно загружена на устройство {device}🎉")
    return model

def _load_similarity_model(self, source_dir: str, models_dir: str):
    # Найти самую свежую модель для сходства
    similarity_files = [f for f in os.listdir(source_dir) if "similarity" in f]
    if similarity_files:
        latest = max(
            similarity_files,
            key=lambda x: os.path.getmtime(os.path.join(source_dir, x)),
        )
        shutil.copy(os.path.join(source_dir, latest), models_dir)
        return torch.load(os.path.join(models_dir, latest))  # Загрузка PyTorch модели
    else:
        raise FileNotFoundError("Модель сходства не найдена")


def get_embedding_model() -> SiameseNetwork:
    global _embedding_model
    if _embedding_model is None:
        lib_logger.info("Модель не обнаружена, загрузка с диска...")
        _embedding_model = _load_model()
    return _embedding_model
"""
