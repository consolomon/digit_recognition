import os
import numpy as np
from matplotlib import pyplot as plt
from PIL import Image
import base64
import io

from .serialization_utils import SerializationUtils
from .learning_engine import LearningEngine, get_random_sample

IMG_TRAIN_DATASET_FILEPATH = "emnist-mnist-train-images-idx3-ubyte"
LAB_TRAIN_DATASET_FILEPATH = "emnist-mnist-train-labels-idx1-ubyte"

WEIGHTS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "weights.data")


def recognize(img_input_vector: np.ndarray) -> int:
    neurons = SerializationUtils.deserialize(WEIGHTS_PATH)
    engine = LearningEngine(neurons)
    return engine.recognize_new(img_input_vector)