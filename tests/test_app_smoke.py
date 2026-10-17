"""Smoke tests for the Flask app: every page answers, every recognize
endpoint returns the shape its page script expects.

Run from the repo root:  venv/bin/python -m unittest discover -s tests -t .

The app is loaded from app/app.py the way gunicorn sees it. DR_APP_DIR
points elsewhere (scripts/dr_rebuild.sh sets it to /app, to test the code
baked into the new image). /stage2/learn is never called: it overwrites the
tracked stage2/weights.data.
"""
import base64
import importlib.util
import io
import os
import sys
import unittest

from PIL import Image

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_DIR = os.environ.get("DR_APP_DIR", os.path.join(REPO_ROOT, "app"))


def load_app():
    spec = importlib.util.spec_from_file_location("dr_app", os.path.join(APP_DIR, "app.py"))
    module = importlib.util.module_from_spec(spec)
    # Flask resolves templates/ and static/ through sys.modules[import_name]
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module.app


app = load_app()


class SmokeTestCase(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()

    def post_json(self, url, payload):
        response = self.client.post(url, json=payload)
        self.assertEqual(response.status_code, 200, response.get_data(as_text=True))
        return response.get_json()


class PagesTest(SmokeTestCase):
    def test_pages_answer(self):
        for url in ("/", "/stage1/", "/stage2/", "/stage3/", "/history/", "/static/style.css"):
            with self.subTest(url=url):
                response = self.client.get(url)
                self.assertEqual(response.status_code, 200)
                response.close()


class Stage1Test(SmokeTestCase):
    def test_recognize_returns_two_probabilities(self):
        data = self.post_json("/stage1/recognize", {"pixels": [0, 1, 0, 0, 1, 0, 0, 1, 0]})
        self.assertEqual(len(data["probabilities"]), 2)


class Stage2Test(SmokeTestCase):
    def test_recognize_returns_digit(self):
        one = [0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]
        data = self.post_json("/stage2/recognize", {"pixels": one})
        self.assertEqual(data["status"], "success", data.get("message"))
        self.assertIn(data["digit"], range(10))
        self.assertIsInstance(data["probability"], float)


class Stage3Test(SmokeTestCase):
    def test_recognize_blank_canvas_returns_digit(self):
        buffer = io.BytesIO()
        Image.new("RGB", (280, 280), "black").save(buffer, format="PNG")
        data_url = "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode()
        data = self.post_json("/stage3/recognize", {"image": data_url})
        self.assertEqual(data["status"], "success", data.get("message"))
        self.assertIn(data["digit"], range(10))


if __name__ == "__main__":
    unittest.main()
