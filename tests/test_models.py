"""Model-level tests: the stage 1 calibration and the stage 2 dataset.

Run from the repo root:  venv/bin/python -m unittest discover -s tests -t .

Imports the stage packages from app/ (or DR_APP_DIR, like the smoke tests).
Nothing here trains or writes app files: the JSON round trip uses a temp dir.
"""
import contextlib
import io
import itertools
import json
import os
import sys
import tempfile
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_DIR = os.environ.get("DR_APP_DIR", os.path.join(REPO_ROOT, "app"))
sys.path.insert(0, APP_DIR)

from stage1.model1 import model1  # noqa: E402
from stage2.learning_engine import LearningEngine  # noqa: E402
from stage2.serialization_utils import SerializationUtils  # noqa: E402

DATASET_PATH = os.path.join(APP_DIR, "stage2", "dataset.json")


def grid(rows):
    return [int(c) for c in rows.replace(" ", "")]


def zero_share(pixels):
    with contextlib.redirect_stdout(io.StringIO()):  # model1 prints every call
        return model1(pixels)[0]


# The labelled set the stage 1 weights were fitted on (rows top to bottom)
STAGE1_ZEROS = [
    "111 101 111", "010 101 010", "011 101 111", "110 101 111", "111 101 011", "111 101 110",
    "010 101 111", "111 101 010", "011 101 110", "110 101 011", "011 101 011", "110 101 110",
    "111 100 111", "111 001 111", "101 101 111", "111 101 101", "011 100 011", "110 001 110",
]
STAGE1_ONES = [
    "010 010 010", "100 100 100", "001 001 001", "110 010 010", "010 010 111", "110 010 111",
    "011 010 010", "010 010 011", "010 010 110", "001 010 100", "100 010 001", "010 010 000",
    "000 010 010", "110 010 000", "100 100 110", "001 001 011", "011 001 001", "110 110 110",
    "011 011 011", "010 110 010", "010 011 010", "110 010 011",
]


class Stage1CalibrationTest(unittest.TestCase):
    def test_reference_digits_are_certain(self):
        self.assertEqual(zero_share(grid("111 101 111")), 1)
        self.assertEqual(zero_share(grid("010 010 010")), 0)

    def test_labelled_grids_on_the_right_side(self):
        for rows in STAGE1_ZEROS:
            with self.subTest(zero=rows):
                self.assertGreater(zero_share(grid(rows)), 0.5)
        for rows in STAGE1_ONES:
            with self.subTest(one=rows):
                self.assertLess(zero_share(grid(rows)), 0.5)

    def test_probabilities_stay_in_range(self):
        for pixels in itertools.product((0, 1), repeat=9):
            with contextlib.redirect_stdout(io.StringIO()):
                p0, p1 = model1(list(pixels))
            self.assertTrue(0 <= p0 <= 1 and 0 <= p1 <= 1, pixels)
            self.assertAlmostEqual(p0 + p1, 1)


class Stage2DatasetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = SerializationUtils.dejsonify(DATASET_PATH)

    def test_loads(self):
        self.assertIsInstance(self.data, dict)
        self.assertEqual(self.data["grid"], {"rows": 5, "cols": 3})

    def test_samples_are_15_binary_cells(self):
        for sample in self.data["training"] + self.data["validation"]:
            self.assertIn(sample["digit"], range(10))
            self.assertEqual(len(sample["pixels"]), 15)
            self.assertLessEqual(set(sample["pixels"]), {0, 1})

    def test_training_is_ideals_plus_three_variations(self):
        training = self.data["training"]
        ideals = [s for s in training if s["kind"] == "ideal"]
        self.assertEqual([s["pixels"] for s in ideals], LearningEngine().training_input_neurons[:10])
        for digit in range(10):
            variations = [s for s in training if s["kind"] == "variation" and s["digit"] == digit]
            self.assertEqual(len(variations), 3, digit)

    def test_validation_is_one_unseen_sample_per_digit(self):
        validation = self.data["validation"]
        self.assertEqual(sorted(s["digit"] for s in validation), list(range(10)))
        training = {tuple(s["pixels"]) for s in self.data["training"]}
        for sample in validation:
            self.assertNotIn(tuple(sample["pixels"]), training, sample)

    def test_no_duplicate_samples(self):
        samples = [tuple(s["pixels"]) for s in self.data["training"] + self.data["validation"]]
        self.assertEqual(len(samples), len(set(samples)))


class Stage2JsonSerializationTest(unittest.TestCase):
    def test_round_trip(self):
        data = {"training": [{"digit": 1, "pixels": [0, 1, 0] * 5}], "validation": [], "name": "x"}
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "dataset.json")
            SerializationUtils.jsonify(data, path)
            with open(path, encoding="utf-8") as f:
                self.assertEqual(json.load(f), data)
            self.assertEqual(SerializationUtils.dejsonify(path), data)

    def test_missing_or_broken_file_gives_none(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(SerializationUtils.dejsonify(os.path.join(tmp, "missing.json")))
            broken = os.path.join(tmp, "broken.json")
            with open(broken, "w", encoding="utf-8") as f:
                f.write("{not json")
            self.assertIsNone(SerializationUtils.dejsonify(broken))


if __name__ == "__main__":
    unittest.main()
