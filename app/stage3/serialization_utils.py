import pickle

class SerializationUtils:
    @staticmethod
    def read(pathname):
        return open(pathname, "r")
    
    @staticmethod
    def serialize(obj, filename):
        with open(filename, "wb") as f:
            pickle.dump(obj, f)

    @staticmethod
    def deserialize(filename):
        with open(filename, "rb") as f:
            return pickle.load(f)