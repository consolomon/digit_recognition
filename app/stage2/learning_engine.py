import math
import os

from .neuron import Neuron
from .ideal_set import IdealSet
from .serialization_utils import SerializationUtils

# Anchor to this file's directory so the weights file resolves regardless of
# the current working directory / launch location.
WEIGHTS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "weights.data")


class LearningEngine:
    def __init__(self):

        # 19 training patterns (each representing variations of digits 0–9)
        self.training_input_neurons = [
            [1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1],
            [0,1,0, 0,1,0, 0,1,0, 0,1,0, 0,1,0],
            [1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1],
            [1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1],
            [1,0,1, 1,0,1, 1,1,1, 0,0,1, 0,0,1],
            [1,1,1, 1,0,0, 1,1,1, 0,0,1, 1,1,1],
            [1,1,1, 1,0,0, 1,1,1, 1,0,1, 1,1,1],
            [1,1,1, 0,0,1, 0,0,1, 0,0,1, 0,0,1],
            [1,1,1, 1,0,1, 1,1,1, 1,0,1, 1,1,1],
            [1,1,1, 1,0,1, 1,1,1, 0,0,1, 1,1,1],
            [0,0,0, 1,1,1, 1,0,1, 1,0,1, 1,1,1],
            [0,0,0, 0,1,0, 0,1,0, 1,1,0, 1,1,0],
            [0,0,0, 1,1,0, 0,0,1, 0,0,1, 1,0,0],
            [0,0,0, 1,1,1, 1,0,1, 0,0,1, 0,0,1],
            [1,1,1, 1,1,1, 0,0,1, 0,0,1, 0,0,0],
            [1,1,1, 1,0,1, 1,1,1, 0,0,1, 0,0,0],
            [0,0,0, 1,1,1, 1,0,1, 1,1,1, 0,0,1],
            [0,0,0, 1,1,1, 1,0,1, 1,0,1, 1,0,1],
            [1,1,1, 1,0,1, 1,0,1, 1,0,1, 0,0,0],
        ]

        # Ideal outputs for digits (10 output neurons)
        self.ideal_set = [
            IdealSet([1,0,0,0,0,0,0,0,0,0]),
            IdealSet([0,1,0,0,0,0,0,0,0,0]),
            IdealSet([0,0,1,0,0,0,0,0,0,0]),
            IdealSet([0,0,0,1,0,0,0,0,0,0]),
            IdealSet([0,0,0,0,1,0,0,0,0,0]),
            IdealSet([0,0,0,0,0,1,0,0,0,0]),
            IdealSet([0,0,0,0,0,0,1,0,0,0]),
            IdealSet([0,0,0,0,0,0,0,1,0,0]),
            IdealSet([0,0,0,0,0,0,0,0,1,0]),
            IdealSet([0,0,0,0,0,0,0,0,0,1]),
            IdealSet([1,0,0,0,0,0,0,0,0,0]),
            IdealSet([0,1,0,0,0,0,0,0,0,0]),
            IdealSet([0,0,1,0,0,0,0,0,0,0]),
            IdealSet([0,0,0,0,0,0,0,1,0,0]),
            IdealSet([0,0,0,0,0,0,0,1,0,0]),
            IdealSet([0,0,0,0,0,0,0,0,0,1]),
            IdealSet([0,0,0,0,0,0,0,0,0,1]),
            IdealSet([1,0,0,0,0,0,0,0,0,0]),
            IdealSet([1,0,0,0,0,0,0,0,0,0]),
        ]

        self.neurons = [Neuron() for _ in range(10)]

    def learn(self, target):

        progress_bar_step = 0
        error = 1
        generation = -1
        progress_percentage_old = 0

        while error > target:
            error = 0
            generation += 1
            number = generation % 19
            pix = self.training_input_neurons[number]

            max_output = 0
            recognized = 0

            for i, neuron in enumerate(self.neurons):
                output_val = neuron.output(pix, self.ideal_set[number].ideal[i])
                error += neuron.error

                if output_val > max_output:
                    recognized = i
                    max_output = output_val

            error = math.sqrt(error)
            if generation == 0:
                progress_bar_step = (error - target) / 100

            # Update weights and biases
            for neuron in self.neurons:
                for j in range(len(pix)):
                    neuron.weights[j] += neuron.delta_w[j]
                neuron.bias += neuron.delta_b

            # Optional debug output (commented out in original Java)
            # if (target < error < target * 1.1) or generation < 10:
            #     print(f"Generation: {generation}, current number: {number}, recognized: {recognized}, error={error:.6f}")

            # CONTINUE TO DO HERE:
            progress_percentage_new = math.floor(100 - (error - target) / progress_bar_step)
            if progress_percentage_new % 10 == 0 and progress_percentage_new > progress_percentage_old:
                progress_percentage_old = progress_percentage_new
                print(f"progress: {progress_percentage_new}")

        # Save the trained neurons

        SerializationUtils.serialize(self.neurons, WEIGHTS_PATH)
        print(f"Training complete after {generation} generations, error={error:.4f}")
        print(f"Weights saved to {WEIGHTS_PATH}")

        return {"generations": generation, "error": f"{error:.4f}"}