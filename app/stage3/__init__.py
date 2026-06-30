import os, sys

# stage3 modules use bare imports (from neuron import Neuron, etc.)
# Add this package's own directory to sys.path so those imports resolve,
# and so pickle can reconstruct serialized Neuron/NeuronLayer objects.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
