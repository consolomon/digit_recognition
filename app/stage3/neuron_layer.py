from neuron import Neuron
import numpy as np
from beartype.door import is_bearable


class NeuronLayer:
    def __init__(self, neurons_or_number, neuron_size=None, is_last=False):
        if is_bearable(neurons_or_number, list):  # copy constructor
            neurons = neurons_or_number
            n = len(neurons)
            self.is_last = is_last
            self.neurons = [Neuron(nr) for nr in neurons[:n]]
            self.delta_w_vector = [[0.0] * len(n.weights) for n in self.neurons]
            self.delta_b_wector = [0.0] * n
        else:
            self.is_last = is_last
            self.neurons = [Neuron(neuron_size, is_output=is_last) for _ in range(neurons_or_number)]
            self.delta_w_vector = [[0.0] * neuron_size] * neurons_or_number
            self.delta_b_wector = [0.0] * neurons_or_number

    
    def add_delta_w_delta_b(self, delta_w_vector, delta_b_vector):
        for i, n in enumerate(self.neurons):
            # print(f" delta_w_vector size:  {np.shape(delta_w_vector)}")
            # print(f" n.delta_w size:  {np.shape(n.delta_w)}")
            n.delta_w += delta_w_vector[i]
            n.delta_b += delta_b_vector[i]


    def update_w_b(self, dataset_size: int, eta) -> float | None:

        layer_error = 0.0
        for i, n in enumerate(self.neurons):

            n.weights = np.array(n.weights) - np.array(n.delta_w) * (eta / dataset_size)
            n.delta_w[:] = 0

            n.bias = n.bias - n.delta_b * (eta / dataset_size)
            n.delta_b = 0

            if self.is_last is True:
                layer_error += n.error
                n.error = 0.0

        if self.is_last is True:
            return layer_error



    def get_output_vector(self):
        return np.array([n.output for n in self.neurons])
    def get_delta_vector(self):
        return np.array([n.delta for n in self.neurons])
    def get_weights_matrix(self):
        return [n.weights for n in self.neurons]
    def get_s_prime_vector(self):
        return [n.s_prime for n in self.neurons]
    
