const ROWS = 3;
const COLS = 3;

const grid = document.getElementById('grid');
const resultEl = document.getElementById('result');

// Build the 3x3 grid of tiles
for (let i = 0; i < ROWS * COLS; i++) {
    const tile = document.createElement('div');
    tile.classList.add('tile');
    tile.addEventListener('click', () => tile.classList.toggle('on'));
    grid.appendChild(tile);
}

// Collect grid state as a flat array of 0/1 values (row-major, top-left = index 0)
function getGridState() {
    return Array.from(grid.querySelectorAll('.tile')).map(t => t.classList.contains('on') ? 1 : 0);
}

document.getElementById('refreshBtn').addEventListener('click', () => {
    grid.querySelectorAll('.tile').forEach(t => t.classList.remove('on'));
    resultEl.innerHTML = '';
});

document.getElementById('recognizeBtn').addEventListener('click', async () => {
    const pixels = getGridState();

    resultEl.textContent = 'Recognizing…';

    try {
        const response = await fetch('/stage1/recognize', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ pixels }),
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        // Expected response shape: { probabilities: [p0, p1] } — floats 0..1
        const data = await response.json();
        const [p0, p1] = data.probabilities;
        const pct = v => `${Math.round(v * 100)}%`;
        resultEl.innerHTML =
            `This is:<br><span class="result-row">0: ${pct(p0)}&nbsp;&nbsp;&nbsp;&nbsp;1: ${pct(p1)}</span>`;
    } catch (err) {
        resultEl.textContent = `Error: ${err.message}`;
    }
});
