import math
import random
import pickle


class Neuron:
    NU = 0.5

    def __init__(self, weights_number: int = 15):

        self.weights = [random.gauss(0, 1) for _ in range(weights_number)]
        self.delta_w = [0.0] * 15

        self.bias = 1
        self.delta_b = 0

        self.error = 0.0

    def get_w(self, j):
        return self.weights[j]

    def set_w(self, j, w):
        self.weights[j] = w

    def _sigmoid(self, x):
        return 1 / (1 + math.exp(-x))
    
    def _sigmoid_derivative(self, x):
        return math.exp(-x) * (self._sigmoid(x) ** 2)

    def output(self, input_vec, ideal=None):
        total = sum(i * w for i, w in zip(input_vec, self.weights)) + self.bias
        out = self._sigmoid(total)

        if ideal is not None:
            self.error = (ideal - out) ** 2
            for i in range(len(self.delta_w)):
                self.delta_w[i] = self.NU * (ideal - out) * self._sigmoid_derivative(total) * input_vec[i]
            self.delta_b = self.NU * (ideal - out) * self._sigmoid_derivative(total)
            
        return out
