import os
import sys

# Make this file's directory importable regardless of the launch location,
# so the stage1/stage2/stage3 packages resolve no matter the working directory.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from flask import Flask, render_template, request, jsonify
from stage1.model1 import model1
import stage2.model2 as model2
import stage3.model3 as model3
from stage3.img import img2vector

app = Flask(__name__, static_folder='static', template_folder='templates')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/stage1/')
def stage1():
    return render_template('stage1.html')

@app.route('/stage1/recognize', methods=['POST'])
def stage1_recognize():
    data = request.get_json()
    pixels = data.get('pixels', [])
    probabilities = model1(pixels)
    return jsonify({'probabilities': probabilities})

@app.route('/stage2/')
def stage2():
    return render_template('stage2.html')

@app.route('/stage2/recognize', methods=['POST'])
def stage2_recognize():
    data = request.get_json()
    pixels = data.get('pixels', [])
    result = model2.recognize(pixels)

    if result['status'] != 'success':
        print(result['message'])

    return jsonify(result)

@app.route('/stage2/learn', methods=['POST'])
def stage2_learn():
    response = model2.learn()
    return jsonify(response)

@app.route('/stage3/')
def stage3():
    return render_template('stage3.html')

@app.route('/stage3/recognize', methods=['POST'])
def stage3_recognize():
    try:
        data = request.get_json()
        image_data = data.get('image', '')
        img_input_vector = img2vector(image_data)
        digit = model3.recognize(img_input_vector)
        return jsonify({'status': 'success', 'digit': digit, 'message': ''})
    except Exception as e:
        return jsonify({'status': 'error', 'message': e})

@app.route('/history/')
def history():
    return render_template('history.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8001, debug=True)
