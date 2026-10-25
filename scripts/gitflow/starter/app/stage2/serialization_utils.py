import json
import pickle

from .neuron import Neuron


class SerializationUtils:
    @staticmethod
    def read(pathname):
        return open(pathname, "r")

    @staticmethod
    def serialize(obj, filename):
        with open(filename, "wb") as f:
            pickle.dump(obj, f)

    @staticmethod
    def deserialize(filename) -> list[Neuron] | None:
        try:
            with open(filename, "rb") as f:
                return pickle.load(f)
        except:
            return None

    @staticmethod
    def jsonify(obj: dict, filename):
        with open(filename, "w", encoding="utf-8") as f:
            f.write(SerializationUtils._to_json(obj) + "\n")

    @staticmethod
    def dejsonify(filename) -> dict | None:
        try:
            with open(filename, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError):
            return None

    @staticmethod
    def _to_json(obj, indent=0, width=100):
        # Indented JSON that keeps every value fitting the line width on one
        # line, so each sample's pixel list stays a single readable row
        flat = json.dumps(obj)
        if not isinstance(obj, (dict, list)) or not obj or indent + len(flat) <= width:
            return flat
        pad = " " * (indent + 2)
        if isinstance(obj, dict):
            items = [f"{pad}{json.dumps(str(k))}: {SerializationUtils._to_json(v, indent + 2, width)}"
                     for k, v in obj.items()]
            return "{\n" + ",\n".join(items) + "\n" + " " * indent + "}"
        items = [pad + SerializationUtils._to_json(v, indent + 2, width) for v in obj]
        return "[\n" + ",\n".join(items) + "\n" + " " * indent + "]"
