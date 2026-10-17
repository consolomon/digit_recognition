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

    def test_page_shell(self):
        # Design-system shell from base.html: frame, scroll window, navbar, partners footer
        for url, active in (("/", None), ("/stage1/", "/stage1/"), ("/stage2/", "/stage2/"),
                            ("/stage3/", "/stage3/"), ("/history/", "/history/")):
            with self.subTest(url=url):
                html = self.client.get(url).get_data(as_text=True)
                for marker in ('class="frame"', 'class="viewport" tabindex="-1" autofocus', 'class="navbar"',
                               'class="partners container"', "@tech_illumination"):
                    self.assertIn(marker, html)
                if active:
                    self.assertIn(f'href="{active}" class="nav-tab active" aria-current="page"', html)
                self.assertEqual(html.count("nav-tab active"), 1 if active else 0)

    def test_page_script_hooks(self):
        # Every id the stage scripts look up must survive a redesign
        hooks = {
            "/stage1/": ("grid", "recognizeBtn", "refreshBtn", "result", "stage1.js"),
            "/stage2/": ("grid", "learnBtn", "recognizeBtn", "refreshBtn", "result", "stage2.js"),
            "/stage3/": ("drawCanvas", "clearBtn", "uploadBtn", "fileInput", "recognizeBtn",
                         "result", "stage3.js"),
            "/history/": ("dashboard-root", "history.js"),
        }
        for url, ids in hooks.items():
            with self.subTest(url=url):
                html = self.client.get(url).get_data(as_text=True)
                for hook in ids:
                    needle = hook if hook.endswith(".js") else f'id="{hook}"'
                    self.assertIn(needle, html)

    def test_design_assets(self):
        for path in ("img/network_bg.webp", "img/partners/sreda_obitaniya.png",
                     "img/partners/tech_prosvet.png"):
            with self.subTest(path=path):
                response = self.client.get(f"/static/{path}")
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
