"""
scripts/utils.py
Вспомогательные функции
"""

import torch
import torch.nn.functional as F
from cv2 import COLOR_RGB2BGR, bilateralFilter, cvtColor
from numpy import array as nparray
from torchvision import transforms
from torchvision.transforms import functional as TF

from .config import STANDARD_DEFINITION


def get_next_int():
    """"""


def get_next_float():
    """"""


def calculate_distance(
    output1: torch.Tensor, output2: torch.Tensor, p: int = 2
) -> torch.Tensor:
    """
    Универсальная функция расчета расстояния между векторами признаков

    Args:
        output1: тензор первого изображения
        output2: тензор второго изображения
        p: степень для расстояния (1 - манхэттен, 2 - евклидово)

    Returns:
        torch.Tensor: расстояние между векторами
    """
    output1 = F.normalize(output1)
    output2 = F.normalize(output2)
    return F.cosine_similarity(output1, output2)
    # return F.pairwise_distance(output1, output2, p=p)


def _calculate_similarity(
    output1: torch.Tensor, output2: torch.Tensor
) -> tuple[torch.Tensor, torch.Tensor]:
    """
    Расчет схожести между двумя векторами признаков

    Args:
        output1: тензор первого изображения
        output2: тензор второго изображения

    Returns:
        torch.Tensor: степени сходства
        torch.Tensor: расстояния между изображениями
    """
    distance = calculate_distance(output1, output2)

    # Преобразуем расстояние в схожесть [0, 1]
    similarity = 1 - distance

    return similarity, distance


# ??? неправильный порядок, см. compare.compare()
def calculate_similarity(
    output1: torch.Tensor, output2: torch.Tensor
) -> tuple[float, float]:
    """
    Расчет схожести между двумя векторами признаков

    Args:
        output1: тензор первого изображения
        output2: тензор второго изображения

    Returns:
        float: степень сходства от 1 (совсем не похожи) до 0 (идентичны)
        float: фактическое расстояние между изображениями
    """
    try:
        similarity, distance = _calculate_similarity(output1, output2)
        return similarity.item(), distance.item()
    except Exception:
        print("💥 Ошибка преобразования расстояния в float")
        return 0, 0


def tensor_to_pil(tensor: torch.Tensor):
    # tensor: (3, H, W) в диапазоне [-1, 1] (из-за Normalize((0.5,),(0.5,)))
    tensor = tensor * 0.5 + 0.5  # -> [0, 1]
    tensor = tensor.clamp(0, 1).cpu()
    to_pil = transforms.ToPILImage()
    return to_pil(tensor)


def get_base_transform(definition: int = STANDARD_DEFINITION):
    """
    Базовые рансформации.
        Вырезают макисмальный квадрат из входного изображения,
        масштабируют его до стандартного разрешения,
        нормализуют, преобразуют в тензор.
    """
    return transforms.Compose(
        [
            transforms.Lambda(
                center_crop_to_square
            ),  # Автоматически определяем размер максимального квадрата
            transforms.Resize((definition, definition)),
            transforms.ToTensor(),
            transforms.Normalize((0.5,), (0.5,)),
        ]
    )


def center_crop_to_square(img: torch.Tensor):
    """Центральная обрезка до максимального квадрата"""
    return TF.center_crop(img, min(img.size))


def inscribed_square_crop(img: torch.Tensor):
    """Обрезка до вписанного квадрата"""
    return TF.center_crop(img, int(min(img.size) / 2**0.5))


def bilateral_filter(img: torch.Tensor):
    return bilateralFilter(
        cvtColor(nparray(img), COLOR_RGB2BGR),
        diameter=15,
        sigma_color=75,
        sigma_space=75,
    )
