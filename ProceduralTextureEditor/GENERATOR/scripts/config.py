"""
scripts/config.py - конфигурация системы
"""

from dataclasses import dataclass
from typing import Any


@dataclass
class TrainingConfig:
    num_epochs: int = 50  # В идеале 50
    learning_rate: float = 1e-4
    weight_decay: float = 1e-4
    triplet_margin: float = 1.0  # Маржа для Triplet Loss
    use_pretrained: bool = (
        False  # Использовать ли предобученную модель или обучать с нуля (False)
    )
    use_ResNet34_weights: bool = False  # Использовать ли веса обученной ResNet34 модели при создании новой модели
    threshold: float = 1.0  # Порог расстояния, меньше которого изображения похожи
    use_attention: bool = True  # Использование внимания
    hard_mining: bool = False  # Использование hard negative mining (False)


# Конфигурация обучения
CONFIG = TrainingConfig()

# Размер вектора признаков
EMBEDDING_DIM: int = 128

# Число эпох без улучшения, после которого модель преждевременно остановит обучение (оптимально в проде - 10)
PATIENCE = 10

# Разрешение изображений внутри модели
STANDARD_DEFINITION: int = 518

# Число троек изображений на класс для обучения
TRIPLETS_PER_IMAGE_CLASS: int = 80
# Число пар изображений на класс для тестирования
TEST_TRIPLETS_PER_IMAGE_CLASS: int = 20

# Конфигурация дата-лоэдеров
DL_CONFIG: dict[str, Any] = {}


def get_config_dict() -> dict[str, Any]:
    """Конвертирует конфиг в словарь для сохранения"""
    return {
        "CONFIG": {
            "num_epochs": CONFIG.num_epochs,
            "learning_rate": CONFIG.learning_rate,
            "weight_decay": CONFIG.weight_decay,
            "triplet_margin": CONFIG.triplet_margin,
            "use_pretrained": CONFIG.use_pretrained,
            "threshold": CONFIG.threshold,
            "use_attention": CONFIG.use_attention,
            "hard_mining": CONFIG.hard_mining,
        },
        "DATA_LOADERS_CONFIG": DL_CONFIG,
        "PATIENCE": PATIENCE,
        "EMBEDDING_DIM": EMBEDDING_DIM,
        "STANDARD_DEFINITION": STANDARD_DEFINITION,
        "TRIPLETS_PER_IMAGE_CLASS": TRIPLETS_PER_IMAGE_CLASS,
        "TEST_TRIPLETS_PER_IMAGE_CLASS": TEST_TRIPLETS_PER_IMAGE_CLASS,
    }
