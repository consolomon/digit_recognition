const ROWS = 5;
const COLS = 3;

const grid = document.getElementById('grid');
const resultEl = document.getElementById('result');

// Override the CSS grid dimensions for this 3x5 layout
grid.style.gridTemplateColumns = `repeat(${COLS}, 60px)`;
grid.style.gridTemplateRows = `repeat(${ROWS}, 60px)`;

// Build the 3x5 grid of tiles
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

document.getElementById('learnBtn').addEventListener('click', async () => {
    resultEl.textContent = 'Learning…';

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 120000);

    try {
        const response = await fetch('/stage2/learn', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            signal: controller.signal,
        });
        clearTimeout(timeoutId);

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        const data = await response.json();
        resultEl.innerHTML = `Learning results: generations: ${data.generations}&nbsp;&nbsp;&nbsp;&nbsp; error: ${data.error}`;
    } catch (err) {
        clearTimeout(timeoutId);
        if (err.name === 'AbortError') {
            resultEl.textContent = 'Error: learning timed out (120s)';
        } else {
            resultEl.textContent = `Error: ${err.message}`;
        }
    }
});

document.getElementById('refreshBtn').addEventListener('click', () => {
    grid.querySelectorAll('.tile').forEach(t => t.classList.remove('on'));
    resultEl.innerHTML = '';
});

document.getElementById('recognizeBtn').addEventListener('click', async () => {
    const pixels = getGridState();

    resultEl.textContent = 'Recognizing…';

    try {
        const response = await fetch('/stage2/recognize', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ pixels }),
        });

        if (!response.ok) {
            throw new Error(`Server error: ${response.status}`);
        }

        // Expected response shape: { status, digit, probability } — probability is a float 0..1
        const data = await response.json();

        if (data.status !== 'success') {
            throw new Error(`Recognition failed: ${data.message}`);
        }
        const pct = v => `${Math.round(v * 100)}%`;
        resultEl.innerHTML =
            `This digit is: ${data.digit}&nbsp;&nbsp;&nbsp;&nbsp;Probability: ${pct(data.probability)}`;
    } catch (err) {
        resultEl.textContent = `Error: ${err.message}`;
    }
});
