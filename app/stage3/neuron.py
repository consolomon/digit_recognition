import math
import copy
import random
import numpy as np

LEAKY_ALPHA = 0.01


class Neuron:

    NU = 0.5

    def __init__(self, input_size_or_original, is_output=False):
        self.is_output = is_output

        if isinstance(input_size_or_original, Neuron):
            original = input_size_or_original
            self.is_output = original.is_output
            self.weights = copy.deepcopy(original.weights)
            self.delta_w = copy.deepcopy(original.delta_w)

            self.bias = copy.deepcopy(original.bias)
            self.delta_b = 0

            self.s_prime = 0
            self.output = 0
            self.delta = 0
            self.error = 0
        else:
            n = input_size_or_original
            std = 1.0 / math.sqrt(n) if is_output else math.sqrt(2.0 / n)
            self.weights = [random.gauss(0, std) for _ in range(n)]
            self.delta_w = np.zeros(n)

            self.bias = 0
            self.delta_b = 0

            self.s_prime = 0
            self.output = 0
            self.delta = 0
            self.error = 0

    def activation(self, a, ideal=None):
        z = self.bias + np.dot(self.weights, a)
        out = self.sigma(z)
        self.output = out
        self.s_prime = self.sigma_prime(z)
        if ideal is not None:
            self.delta = out - ideal
            self.error += -(ideal * math.log(out + 1e-10) + (1 - ideal) * math.log(1 - out + 1e-10))

    def sigma(self, x):
        if self.is_output:
            x = np.clip(x, -256, 256)
            return 1 / (1 + math.e ** (-1.0 * x))
        x = float(x)
        return x if x > 0 else LEAKY_ALPHA * x

    def sigma_prime(self, x):
        if self.is_output:
            s = self.sigma(x)
            return s * (1 - s)
        return 1.0 if x > 0 else LEAKY_ALPHA