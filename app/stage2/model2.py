import os

from .serialization_utils import SerializationUtils
from .learning_engine import LearningEngine
from .neuron import Neuron


# Anchor to this file's directory so the weights file resolves regardless of
# the current working directory / launch location.
WEIGHTS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "weights.data")
TARGET_PRECISION = 0.005

def learn():
    return LearningEngine().learn(TARGET_PRECISION)

def recognize(input_grid: list[int]):

    neurons = SerializationUtils.deserialize(WEIGHTS_PATH)
    if neurons is not None:
        print("Model uploaded, ready to recognize digits")
    else:
        return {"status": "error", "message": "Model isn't connected! Try to train model (option 1) or upload model from file (option 2)"}

    max_output = 0
    digit = 0

    for i, neuron in enumerate(neurons):
        output = neuron.output(input_grid)
        if output > max_output:
            digit = i
            max_output = output

    print(f"This number is {digit}, probability: {max_output:.3f}")
    return {"status": "success", "digit": digit, "probability": max_output}