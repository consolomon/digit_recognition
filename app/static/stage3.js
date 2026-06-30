const canvas = document.getElementById('drawCanvas');
const ctx = canvas.getContext('2d');
const resultEl = document.getElementById('result');

let isDrawing = false;
let uploadedFile = null;

// Black background — matches MNIST convention (white digit on black)
function clearCanvas() {
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
}
clearCanvas();

ctx.strokeStyle = '#ffffff';
ctx.lineWidth = 20;
ctx.lineCap = 'round';
ctx.lineJoin = 'round';

function getPos(e) {
    const rect = canvas.getBoundingClientRect();
    return {
        x: (e.clientX - rect.left) * (canvas.width / rect.width),
        y: (e.clientY - rect.top) * (canvas.height / rect.height),
    };
}

// ── Mouse events ──
canvas.addEventListener('mousedown', (e) => {
    isDrawing = true;
    const { x, y } = getPos(e);
    ctx.beginPath();
    ctx.moveTo(x, y);
});

canvas.addEventListener('mousemove', (e) => {
    if (!isDrawing) return;
    const { x, y } = getPos(e);
    ctx.lineTo(x, y);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(x, y);
});

canvas.addEventListener('mouseup', () => { isDrawing = false; });
canvas.addEventListener('mouseleave', () => { isDrawing = false; });

// ── Touch events ──
canvas.addEventListener('touchstart', (e) => {
    e.preventDefault();
    isDrawing = true;
    const { x, y } = getPos(e.touches[0]);
    ctx.beginPath();
    ctx.moveTo(x, y);
}, { passive: false });

canvas.addEventListener('touchmove', (e) => {
    e.preventDefault();
    if (!isDrawing) return;
    const { x, y } = getPos(e.touches[0]);
    ctx.lineTo(x, y);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(x, y);
}, { passive: false });

canvas.addEventListener('touchend', () => { isDrawing = false; });

// ── Clear button ──
document.getElementById('clearBtn').addEventListener('click', () => {
    clearCanvas();
    uploadedFile = null;
    resultEl.innerHTML = '';
    document.getElementById('fileInput').value = '';
});

// ── Upload button ──
document.getElementById('uploadBtn').addEventListener('click', () => {
    document.getElementById('fileInput').click();
});

document.getElementById('fileInput').addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (!file) return;
    uploadedFile = file;

    const img = new Image();
    const objectUrl = URL.createObjectURL(file);
    img.onload = () => {
        clearCanvas();
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
        URL.revokeObjectURL(objectUrl);
    };
    img.src = objectUrl;
});

// ── Recognize button ──
document.getElementById('recognizeBtn').addEventListener('click', async () => {
    resultEl.textContent = 'Recognizing…';

    // Canvas always holds the current image — drawn or uploaded.
    // If a file was uploaded, re-draw it fresh before encoding so the
    // server always receives a clean 280×280 PNG regardless of source.
    if (uploadedFile) {
        await new Promise((resolve) => {
            const img = new Image();
            const objectUrl = URL.createObjectURL(uploadedFile);
            img.onload = () => {
                clearCanvas();
                ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                URL.revokeObjectURL(objectUrl);
                resolve();
            };
            img.src = objectUrl;
        });
    }

    const dataURL = canvas.toDataURL('image/png');

    try {
        const response = await fetch('/stage3/recognize', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ image: dataURL }),
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();

        if (data.status !== 'success') {
            throw new Error(data.message || 'Recognition failed');
        }

        resultEl.innerHTML =
            `Recognized digit is: ${data.digit}`;
    } catch (err) {
        resultEl.textContent = `Error: ${err.message}`;
    }
});
