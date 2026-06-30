import base64
import io
import numpy as np
from PIL import Image


def img2vector(data_url: str) -> np.ndarray:
    _, encoded = data_url.split(',', 1)
    img = Image.open(io.BytesIO(base64.b64decode(encoded))).convert('L')
    img = img.resize((28, 28), Image.LANCZOS)
    arr = np.array(img, dtype=np.float32)   # shape (28, 28)
    return arr.flatten('C') / 255.0         # shape (784,), values 0.0–1.0
