# project/lib/__init__.py
"""
MaterialAnalyzer - библиотека для анализа текстур и сравнения изображений
"""

from .scripts import models_manager

from .scripts import visualization
from .core import (
    # MetodParameters,
    # Embedding,
    # Metod,
    # EmbeddingNode,
    build_embedding_graph,
    # compare_images,
    # get_embeddings,
    compare_images,
    add_to_embedding_graph,
    find_similar_clusters,
)

# from . import utils

__version__ = "0.0.3"
__all__ = [
    #'MetodParameters',
    #'Embedding',
    #'Metod',
    #'EmbeddingNode',
    "EmbeddingGraph",
    #'compare_images',
    #'get_embeddings',
    "ImageSimilarityLibrary",
    "models_manager",
    "visualization",
    #'utils'
]
