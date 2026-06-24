"""
scripts/seames_network.py
Сиамская нейросеть для определения степени сходства изображений
"""

from typing import Tuple

import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import models

from .config import EMBEDDING_DIM


class AttentionModule(nn.Module):
    """Модуль внимания для выделения важных признаков"""

    def __init__(self, channels):
        super(AttentionModule, self).__init__()
        self.channel_attention = nn.Sequential(
            nn.AdaptiveAvgPool2d(1),
            nn.Conv2d(channels, max(channels // 8, 1), 1),
            nn.ReLU(),
            nn.Conv2d(max(channels // 8, 1), channels, 1),
            nn.Sigmoid(),
        )

        self.spatial_attention = nn.Sequential(
            nn.Conv2d(2, 1, kernel_size=7, padding=3), nn.Sigmoid()
        )

    def forward(self, x):
        # Канальное внимание
        ca = self.channel_attention(x)
        x = x * ca

        # Пространственное внимание
        avg_out = torch.mean(x, dim=1, keepdim=True)
        max_out, _ = torch.max(x, dim=1, keepdim=True)
        sa_input = torch.cat([avg_out, max_out], dim=1)
        sa = self.spatial_attention(sa_input)
        x = x * sa

        return x


class ModernSiameseNetwork(nn.Module):
    def __init__(
        self,
        use_pretrained: bool = True,
        use_ResNet34_weights: bool = True,
        embedding_dim: int = EMBEDDING_DIM,
    ):
        super(ModernSiameseNetwork, self).__init__()

        # Используем мощную архитектуру
        weights = (
            models.ResNet34_Weights.DEFAULT
            if not use_pretrained and use_ResNet34_weights
            else None
        )  # РАссмотреть RestNet-18
        backbone = models.resnet34(weights=weights)

        # Заменяем первый слой для grayscale
        original_conv1 = backbone.conv1
        backbone.conv1 = nn.Conv2d(
            1, 64, kernel_size=7, stride=2, padding=3, bias=False
        )

        # Инициализируем веса нового слоя
        if use_pretrained:
            with torch.no_grad():
                mean_weights = original_conv1.weight.data.mean(dim=1, keepdim=True)
                backbone.conv1.weight.data = mean_weights

        # Извлекаем слои до layer4
        self.layer0 = nn.Sequential(
            backbone.conv1, backbone.bn1, backbone.relu, backbone.maxpool
        )
        self.layer1 = backbone.layer1  # 64 канала
        self.layer2 = backbone.layer2  # 128 каналов
        self.layer3 = backbone.layer3  # 256 каналов
        self.layer4 = backbone.layer4  # 512 каналов

        # Добавляем attention модули
        self.attention1 = AttentionModule(64)  # для layer1 (64 канала)
        self.attention2 = AttentionModule(128)  # для layer2 (128 каналов)
        self.attention3 = AttentionModule(256)  # для layer3 (256 каналов)
        self.attention4 = AttentionModule(512)  # для layer4 (512 каналов)

        # Глобальный pooling с вниманием
        self.global_pool = nn.AdaptiveAvgPool2d(1)

        # Улучшенная система эмбеддингов
        self.embedding = nn.Sequential(
            nn.Linear(512, 512),
            nn.BatchNorm1d(512),
            nn.ReLU(inplace=True),
            nn.Dropout(0.4),
            nn.Linear(512, 256),
            nn.BatchNorm1d(256),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            nn.Linear(256, embedding_dim),
            nn.BatchNorm1d(embedding_dim),
        )

        # Инициализация весов
        self._initialize_weights()

    def _initialize_weights(self):
        for m in self.modules():
            if isinstance(m, nn.Conv2d):
                nn.init.kaiming_normal_(m.weight, mode="fan_out", nonlinearity="relu")
                if m.bias is not None:
                    nn.init.constant_(m.bias, 0)
            elif isinstance(m, nn.BatchNorm2d) or isinstance(m, nn.BatchNorm1d):
                nn.init.constant_(m.weight, 1)
                nn.init.constant_(m.bias, 0)
            elif isinstance(m, nn.Linear):
                nn.init.normal_(m.weight, 0, 0.01)
                if m.bias is not None:
                    nn.init.constant_(m.bias, 0)

    def forward_one(self, x: torch.Tensor) -> torch.Tensor:
        # Прямой проход с attention
        x = self.layer0(x)  # 64 канала

        x = self.layer1(x)  # 64 канала
        x = self.attention1(x)

        x = self.layer2(x)  # 128 каналов
        x = self.attention2(x)

        x = self.layer3(x)  # 256 каналов
        x = self.attention3(x)

        x = self.layer4(x)  # 512 каналов
        x = self.attention4(x)

        # Global pooling
        x = self.global_pool(x)
        x = x.view(x.size(0), -1)

        # Эмбеддинг
        x = self.embedding(x)

        # L2 нормализация
        return F.normalize(x, p=2, dim=1)

    def forward(
        self, input1: torch.Tensor, input2: torch.Tensor
    ) -> Tuple[torch.Tensor, torch.Tensor]:
        output1 = self.forward_one(input1)
        output2 = self.forward_one(input2)
        return output1, output2


class SiameseNetwork(nn.Module):
    def __init__(self, use_pretrained: bool = True):
        super(SiameseNetwork, self).__init__()

        # Современный способ загрузки предобученных весов
        weights = models.ResNet18_Weights.DEFAULT if use_pretrained else None
        backbone = models.resnet18(weights=weights)

        # Заменяем первый слой для grayscale (1 канал вместо 3)
        original_conv1 = backbone.conv1
        backbone.conv1 = nn.Conv2d(
            1, 64, kernel_size=7, stride=2, padding=3, bias=False
        )

        # Инициализируем веса нового слоя (усредняем по RGB каналам)
        if use_pretrained:
            with torch.no_grad():
                # Берем среднее по каналам RGB для инициализации grayscale
                mean_weights = original_conv1.weight.data.mean(dim=1, keepdim=True)
                backbone.conv1.weight.data = mean_weights

        # Удаляем последний FC слой
        self.backbone = nn.Sequential(*list(backbone.children())[:-1])

        # Добавляем свои слои
        self.embedding = nn.Sequential(
            nn.Linear(512, 256),
            nn.BatchNorm1d(256),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            nn.Linear(256, EMBEDDING_DIM),
            nn.BatchNorm1d(EMBEDDING_DIM),
        )

        # Инициализация весов
        self._initialize_weights()

    def _initialize_weights(self):
        for m in self.modules():
            if isinstance(m, nn.Conv2d):
                nn.init.kaiming_normal_(m.weight, mode="fan_out", nonlinearity="relu")
            elif isinstance(m, nn.BatchNorm2d) or isinstance(m, nn.BatchNorm1d):
                nn.init.constant_(m.weight, 1)
                nn.init.constant_(m.bias, 0)

    def forward_one(self, x: torch.Tensor) -> torch.Tensor:
        x = self.backbone(x)
        x = x.view(x.size(0), -1)
        x = self.embedding(x)
        # L2 нормализация для стабильного обучения
        return F.normalize(x, p=2, dim=1)

    def forward(
        self, input1: torch.Tensor, input2: torch.Tensor
    ) -> Tuple[torch.Tensor, torch.Tensor]:
        output1 = self.forward_one(input1)
        output2 = self.forward_one(input2)
        return output1, output2


# Сохраняем обратную совместимость
# SiameseNetwork = ModernSiameseNetwork

"""
Альтернативные модели, на случай, если не сработает:
1.   Swin Transformer (Swin-B): должна хорошо справляться с текстурами, за счёт её иерархической архитектуры,
     помогающей эффективно выделять детали на разных масштабах.

2.   BeiTv2: считается мощной моделью для текстур, показывающей высокую точность в задачах классификации.

3.   ResNet50 (с предобучением на ImageNet) - традиционная CNN. Скорее всего потребует дополнительной настройки,
     так как стандартная ResNet может сильнее фокусироваться на текстурах, чем ViT.

Для ааптации альтернативных моделей нужно:
*   Удалить "голову", как с DINOv2. Загрузить через AutoModel, получив "голое" тело сети, чей выход
    (last_hidden_state или pooler_output) и есть эмбеддинг. AutoModel не содержит последний слой классификатор.

*   ResNet50: в библиотеке torchvision можно использовать параметр weights='IMAGENET1K_V1' и удалить последний слой
    (model.fc = torch.nn.Identity()).
"""
