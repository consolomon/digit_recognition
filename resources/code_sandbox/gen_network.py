"""Generate the decorative particle-network SVG (poster's lower-half network, stylised).
Deterministic: seed 28. Usage: python gen_network.py out.svg"""
import math, random, sys
random.seed(28)
W, H = 1600, 640
LAYERS = [  # count, r-min, r-max, y-spread, y-offset, k-neighbours
    (300, 0.5, 1.0, 50, 0, 4),
    (150, 0.9, 1.7, 110, 80, 3),
    (55, 1.5, 2.6, 190, 190, 3),
]
nodes = []
for l, (n, rmin, rmax, spread, off, _) in enumerate(LAYERS):
    for i in range(n):
        x = (i + random.random()) * (W + 80) / n - 40          # stratified in x: no holes
        ridge = H * 0.58 - 0.24 * H * (x / W) + 26 * math.sin(x / 190 + l) + 14 * math.sin(x / 61)
        y = ridge + abs(random.gauss(0, spread)) * (1 if l else random.choice((1, -0.5))) + off
        nodes.append((x, max(8, min(H + 20, y)), random.uniform(rmin, rmax), l))
lines = set()
for i, (x, y, _, l) in enumerate(nodes):
    near = sorted((math.hypot(x - a, y - b), j) for j, (a, b, _, m) in enumerate(nodes) if j != i and m == l)
    for _, j in near[:LAYERS[l][5]]:
        lines.add(tuple(sorted((i, j))))
for _ in range(70):  # depth links between neighbouring layers
    i = random.randrange(len(nodes)); a = nodes[i]
    cand = [j for j, b in enumerate(nodes) if b[3] == min(2, a[3] + 1) and math.hypot(a[0] - b[0], a[1] - b[1]) < 150]
    if cand:
        lines.add(tuple(sorted((i, random.choice(cand)))))
f = lambda v: ("%.1f" % v).rstrip("0").rstrip(".")
out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" preserveAspectRatio="xMidYMax slice">']
for l, (sw, op) in enumerate([(0.5, 0.18), (0.7, 0.28), (1.0, 0.45)]):
    d = "".join(f"M{f(nodes[i][0])} {f(nodes[i][1])}L{f(nodes[j][0])} {f(nodes[j][1])}"
                for i, j in sorted(lines) if max(nodes[i][3], nodes[j][3]) == l)
    out.append(f'<path d="{d}" fill="none" stroke="#fff" stroke-opacity="{op}" stroke-width="{sw}"/>')
for l, op in enumerate((0.45, 0.7, 0.95)):
    out.append(f'<g fill="#fff" fill-opacity="{op}">' + "".join(
        f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}"/>' for x, y, r, m in nodes if m == l) + "</g>")
out.append('<g fill="#fff" fill-opacity="0.07">' + "".join(
    f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r * 6)}"/>' for x, y, r, m in nodes[-55::8]) + "</g></svg>")
open(sys.argv[1], "w").write("".join(out))
print(sum(map(len, out)), "bytes", len(nodes), "nodes", len(lines), "lines")
