import copy
import random
import math
import numpy as np
import struct
from .neuron import Neuron
from .serialization_utils import SerializationUtils
from .neuron_layer import NeuronLayer
from beartype.door import is_bearable

IMG_TRAIN_DATASET_FILEPATH = "emnist-mnist-train-images-idx3-ubyte"
LAB_TRAIN_DATASET_FILEPATH = "emnist-mnist-train-labels-idx1-ubyte"

IMG_TEST_DATASET_FILEPATH = "emnist-mnist-test-images-idx3-ubyte"
LAB_TEST_DATASET_FILEPATH = "emnist-mnist-test-labels-idx1-ubyte"

BATCH_SIZE = 200
ETA = 0.1


class LearningEngine:
    def __init__(self, arg, input_size: int = None):
        if is_bearable(arg, list[int]):  # neuronsNumber list
            neurons_number = arg
            neurons_number.insert(0, input_size)
            self.neuron_layers = [
                NeuronLayer(
                    neurons_number[i],
                    neurons_number[i - 1],
                    is_last=(i == len(neurons_number) - 1)
                )
                for i in range(1, len(neurons_number))
            ]
        else:  # learnedLayers
            self.neuron_layers = arg
    
    def learn(self, target: float = 0.01, pathname = "weights.data"):

        img_train_dataset, lab_train_dataset = get_dataset(IMG_TRAIN_DATASET_FILEPATH, LAB_TRAIN_DATASET_FILEPATH)
        
        error = 1
        generation = 0
        eta_g = ETA

        while error > target and generation <= 20:

            generation += 1
            eta_g = eta_g * 0.9

            dataset_size = len(lab_train_dataset)
            shuffle_idx = np.random.permutation(dataset_size)
            img_epoch = img_train_dataset[shuffle_idx]
            lab_epoch = lab_train_dataset[shuffle_idx]

            for i in range(dataset_size):
                img_input_vector = np.transpose(img_epoch[i,:,:]).flatten("C") / 255.0
                lab_output_ideal = lab_epoch[i]
                delta_vector = self.recognition(img_input_vector, lab_output_ideal, True)

                self.backpropagation(delta_vector, img_input_vector)

                if i % BATCH_SIZE == 0 or i == dataset_size - 1:
                    error = self.update_w_b(BATCH_SIZE, eta_g)
                    if i % 6000 == 0:
                        print(f"Learning progress: {i / 600}%, error={error}")
            

            print(f"{generation} generation complete, begin test...")

            accuracy = self.test()

            print(f"Accuracy on test is: {accuracy}%")

            random_input, random_digit = get_random_sample(IMG_TRAIN_DATASET_FILEPATH, LAB_TRAIN_DATASET_FILEPATH)
            recognized = self.recognition(random_input, random_digit)

            print(f"random digit is: {random_digit}")
            print(f"recognized digit is: {recognized}")


            
            
        SerializationUtils.serialize(self.neuron_layers, pathname)
        print(f"Training complete after {generation} generations, error={error:.6f}")
        print(f"Weights saved to {pathname}")

    def recognition(self, img_input_vector: np.ndarray, lab_output_ideal: int, learning: bool = False):
        input_vector = copy.deepcopy(img_input_vector)
        response_vector = []
        delta_vector = []
        for l, layer in enumerate(self.neuron_layers):
            if l != len(self.neuron_layers) - 1:
                for neuron in layer.neurons:
                    neuron.activation(input_vector)
                input_vector = layer.get_output_vector()
            else:
                output_ideal_vector = [1.0 if i == int(lab_output_ideal) else 0.0 for i in range(len(layer.neurons))]
                for i, neuron in enumerate(layer.neurons):
                    neuron.activation(input_vector, output_ideal_vector[i])
                response_vector = layer.get_output_vector()
                delta_vector = layer.get_delta_vector()
        if learning is False:
            return int(np.argmax(response_vector))
        else:
            return delta_vector

    def recognize_new(self, img_input_vector: np.ndarray) -> int:
        input_vector = copy.deepcopy(img_input_vector)
        for layer in self.neuron_layers:
            for neuron in layer.neurons:
                neuron.activation(input_vector)
            input_vector = layer.get_output_vector()
        return int(np.argmax(input_vector))
    
    def backpropagation(self, d_vector: np.ndarray, img_input_vector: np.ndarray):
        delta_vector = copy.deepcopy(d_vector)
        for l in range(len(self.neuron_layers) - 1, -1, -1):
            delta_b_vector = delta_vector
            if l > 0:
                input_vector = np.array(self.neuron_layers[l-1].get_output_vector())
            else:
                input_vector = np.array(copy.deepcopy(img_input_vector))
            delta_w_vector = np.outer(delta_vector, input_vector)
            self.neuron_layers[l].add_delta_w_delta_b(delta_w_vector, delta_b_vector)
            if l > 0:
                delta_vector = np.dot(np.array(self.neuron_layers[l].get_weights_matrix()).transpose(), delta_vector) * np.array(self.neuron_layers[l-1].get_s_prime_vector())
    
    def update_w_b(self, dataset_size, eta):
        global_error = 0.0
        layers_number = len(self.neuron_layers)
        for l in range(layers_number - 1, -1, -1):
            if l == layers_number - 1: 
                global_error += self.neuron_layers[l].update_w_b(dataset_size, eta)
            else:
                self.neuron_layers[l].update_w_b(dataset_size, eta)
        
        return round(global_error / dataset_size, 5)
    
    def test(self) -> float:
        img_test_dataset, lab_test_dataset = get_dataset(IMG_TEST_DATASET_FILEPATH, LAB_TEST_DATASET_FILEPATH)
        dataset_size = len(lab_test_dataset)
        shuffle_idx = np.random.permutation(dataset_size)
        img_epoch = img_test_dataset[shuffle_idx]
        lab_epoch = lab_test_dataset[shuffle_idx]

        accuracy = 0.0

        for i in range(dataset_size):
            img_input_vector = np.transpose(img_epoch[i,:,:]).flatten("C") / 255.0
            lab_output_ideal = lab_epoch[i]
            response = self.recognition(img_input_vector, lab_output_ideal)
            accuracy += 1 if response == lab_output_ideal else 0
        return round(accuracy / dataset_size, 4) * 100



def get_dataset(img_filepath: str, lab_filepath: str) -> np.ndarray:

    with open(img_filepath,'rb') as f_img:
        magic, size = struct.unpack(">II", f_img.read(8))
        print(f"dataset size: {size}")
        nrows, ncols = struct.unpack(">II", f_img.read(8))
        data_img = np.fromfile(f_img, dtype=np.dtype(np.uint8).newbyteorder('>'))
        data_img = data_img.reshape((size, nrows, ncols))
        

    with open(lab_filepath,'rb') as f_lab:
        magic, size = struct.unpack(">II", f_lab.read(8))
        data_lab = np.fromfile(f_lab, dtype=np.dtype(np.uint8).newbyteorder('>'))
        data_lab = data_lab.reshape((size,))
    
    return data_img, data_lab


def get_random_sample(img_filepath: str, lab_filepath: str):

    with open(img_filepath,'rb') as f_img:
        
        magic, size = struct.unpack(">II", f_img.read(8))

        i = random.randint(1, size - 1)

        nrows, ncols = struct.unpack(">II", f_img.read(8))
        data_img = np.fromfile(f_img, dtype=np.dtype(np.uint8).newbyteorder('>'))
        data_img = data_img.reshape((size, nrows, ncols))
        img_input_vector = np.transpose(data_img[i,:,:]).flatten("C") / 255.0


        with open(lab_filepath,'rb') as f_lab:
            magic, size = struct.unpack(">II", f_lab.read(8))
            data_lab = np.fromfile(f_lab, dtype=np.dtype(np.uint8).newbyteorder('>'))
            data_lab = data_lab.reshape((size,))
            lab_output_ideal = data_lab[i]
    
    return img_input_vector, lab_output_ideal