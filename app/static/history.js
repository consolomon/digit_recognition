(function () {
  const e = React.createElement;
  const { useState } = React;
  const {
    LineChart, Line, XAxis, YAxis, CartesianGrid,
    Tooltip: RechartsTooltip, ResponsiveContainer, ReferenceLine, ReferenceDot,
  } = Recharts;

  const milestones = [
    {
      year: 1989, error: null, label: "MNIST Created",
      method: "CNN + BP (LeCun et al.)",
      detail: "Backpropagation applied to convolutional neural layers; MNIST dataset introduced. Became 'perhaps the most famous benchmark of Machine Learning.'",
      color: "#38bdf8", isOrigin: true,
      sourceUrl: "https://doi.org/10.1162/neco.1989.1.4.541",
      sourceLabel: "LeCun et al. 1989 — Neural Computation",
    },
    {
      year: 1994, error: null, label: "MNIST Dataset Compiled",
      method: "LeCun, Cortes, Burges (AT&T Bell Labs / NIST)",
      detail: "Mixed from NIST's SD-1 and SD-3 special databases; 60,000 training and 10,000 test images normalised to 28\xD728 pixels with anti-aliasing. Half the samples come from U.S. Census Bureau employees (SD-3) and half from high-school students (SD-7), balancing writer populations. The test set contains at least 4 known mislabelled images — a fact that bounds the theoretical minimum achievable error for any model.",
      color: "#a78bfa", isOrigin: true,
      sourceUrl: "https://arxiv.org/abs/1905.10498",
      sourceLabel: "Yadav & Bottou 2019 — arXiv:1905.10498",
    },
    {
      year: 1998, error: 0.80, label: "LeNet-5 & SVM Baseline",
      method: "Support vector machine (LeCun et al.)",
      detail: "LeCun et al.'s landmark 'Gradient-Based Learning Applied to Document Recognition' introduced the LeNet-5 architecture and set the SVM baseline at 0.80% error, cementing MNIST as the standard benchmark. Convolutional layers, pooling, and end-to-end backpropagation — introduced here — remain foundational to modern vision models.",
      color: "#818cf8",
      sourceUrl: "https://doi.org/10.1109/5.726791",
      sourceLabel: "LeCun et al. 1998 — Proc. IEEE 86(11)",
    },
    {
      year: 2003, error: 0.40, label: "CNN + Distortions",
      method: "CNN + elastic deformations (Simard et al.)",
      detail: "BP-trained CNN set record of 0.40% using training pattern deformations but no unsupervised pre-training. Standard BP net achieved 0.70%.",
      color: "#0ea5e9",
      sourceUrl: "https://doi.org/10.1109/ICDAR.2003.1227801",
      sourceLabel: "Simard et al. 2003 — ICDAR",
    },
    {
      year: 2006, error: 1.20, label: "Deep Belief Network",
      method: "DBN + BP fine-tuning (Hinton & Salakhutdinov)",
      detail: "DBN achieved 1.2% without deformations. Demonstrated unsupervised pre-training can help deep nets; coined the term 'Deep Learning.'",
      color: "#f59e0b", isDBN: true,
      sourceUrl: "https://arxiv.org/abs/1404.7828",
      sourceLabel: "Schmidhuber 2014 — arXiv:1404.7828",
    },
    {
      year: 2006.3, error: 0.39, label: "Improved CNN",
      method: "CNN + deformations (Ranzato et al.)",
      detail: "New MNIST record of 0.39%. Same year saw the first GPU-based CNN implementation (4\xD7 faster than CPU).",
      color: "#0ea5e9",
      sourceUrl: "https://arxiv.org/abs/1404.7828",
      sourceLabel: "Schmidhuber 2014 — arXiv:1404.7828",
    },
    {
      year: 2010, error: 0.35, label: "GPU + Plain BP",
      method: "Standard deep NN + BP on GPU (Ciresan et al.)",
      detail: "Record 0.35% using plain backprop on GPU (50\xD7 faster than CPU). No convolution, no unsupervised pre-training. 'Hardware advances more important than algorithms.'",
      color: "#10b981",
      sourceUrl: "https://arxiv.org/abs/1003.0358",
      sourceLabel: "Ciresan et al. 2010 — arXiv:1003.0358",
    },
    {
      year: 2011, error: 0.20, label: "GPU-MPCNN Ensemble",
      method: "Multi-Column GPU-MPCNN (Ciresan et al.)",
      detail: "First human-competitive performance (~0.2%) on MNIST. 'A dramatic improvement, since the record had hovered around 0.4% for almost a decade.' Same architecture achieved first superhuman result on traffic signs.",
      color: "#ef4444",
      sourceUrl: "https://arxiv.org/abs/1202.2745",
      sourceLabel: "Ciresan et al. 2012 — arXiv:1202.2745",
    },
    {
      year: 2013, error: 0.21, label: "DropConnect",
      method: "DropConnect regularization (Wan et al.)",
      detail: "DropConnect (Wan et al., ICML 2013) generalises Dropout by randomly zeroing individual weights rather than full neuron outputs during training. It achieved 0.21% error as a strong single-model result — just above the 2011 ensemble record of 0.20%, but notable for requiring no data augmentation or multi-column ensembling.",
      color: "#f97316",
      excludeFromChart: true,
      sourceUrl: "https://proceedings.mlr.press/v28/wan13.html",
      sourceLabel: "Wan et al. 2013 — ICML (PMLR v28)",
    },
    {
      year: 2020, error: 0.17, label: "SE-Network Committee",
      method: "Committee of 20 CNNs with Squeeze-and-Excitation Networks",
      detail: "A committee of 20 CNNs with Squeeze-and-Excitation (SE) channel-attention blocks achieved 0.17% error, well below estimated human-level performance. SE blocks learn per-channel importance weights, letting the network suppress uninformative feature maps. SE-Net architecture introduced by Hu et al. (arXiv:1709.01507).",
      color: "#ec4899",
      sourceUrl: "https://github.com/Matuzas77/MNIST-0.17",
      sourceLabel: "Matuzas 2020 — github.com/Matuzas77/MNIST-0.17",
    },
    {
      year: 2020.5, error: 0.09, label: "Near-Perfect Ensemble",
      method: "Ensemble of 3 CNNs with rotation/translation augmentation (An et al.)",
      detail: "An ensemble of 3 CNNs with rotation and translation augmentation achieved 0.09% error — less than half the human baseline of ~0.20% and approaching the theoretical floor set by the dataset's own mislabelled images. MNIST is now widely considered a solved benchmark.",
      color: "#06b6d4",
      sourceUrl: "https://arxiv.org/abs/2008.10400",
      sourceLabel: "An et al. 2020 — arXiv:2008.10400",
    },
  ];

  const chartData = milestones
    .filter(m => m.error !== null && !m.excludeFromChart)
    .map(m => ({ year: Math.floor(m.year), error: m.error, label: m.label }));

  const humanError = 0.20;

  function CustomDot({ cx, cy, payload }) {
    const m = milestones.find(mi => Math.floor(mi.year) === payload.year && mi.error === payload.error);
    const fill = m ? m.color : "#38bdf8";
    return e('circle', {
      cx, cy, r: 7, fill, stroke: "#fff", strokeWidth: 2,
      style: { filter: "drop-shadow(0 1px 3px rgba(0,0,0,0.3))" },
    });
  }

  function CustomTooltip({ active, payload }) {
    if (!active || !payload || !payload.length) return null;
    const d = payload[0].payload;
    const m = milestones.find(mi => Math.floor(mi.year) === d.year && mi.error === d.error);
    if (!m) return null;
    return e('div', {
      style: {
        background: "#0c0f1a", border: "2px solid " + m.color, borderRadius: 10,
        padding: "14px 18px", maxWidth: 320, color: "#e8edf5", fontSize: 13,
        lineHeight: 1.5, boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
        fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
      },
    },
      e('div', { style: { fontWeight: 700, fontSize: 15, color: "#fff", marginBottom: 4 } },
        m.label + " (" + Math.floor(m.year) + ")"),
      e('div', { style: { color: m.color, fontWeight: 600, marginBottom: 6 } },
        "Error: " + m.error + "%"),
      e('div', { style: { fontSize: 12, color: "#7c8a9e", marginBottom: 8 } }, m.method),
      e('div', { style: { fontSize: 12, color: "#aab4c4" } }, m.detail),
      e('div', {
        style: { marginTop: 10, paddingTop: 8, borderTop: "1px solid #333", fontSize: 11, color: "#7c8a9e" },
      }, "📄 " + m.sourceLabel)
    );
  }

  function MNISTDashboard() {
    const [selected, setSelected] = useState(null);

    return e('div', {
      style: {
        color: "#e8edf5",
        fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
        width: "100%",
      },
    },

      // Header
      e('div', { style: { maxWidth: 900, margin: "0 auto 32px" } },
        e('h1', {
          style: { fontSize: 28, fontWeight: 800, color: "#fff", margin: "0 0 8px", lineHeight: 1.2 },
        }, "MNIST Error Rate Milestones"),
        e('p', { style: { fontSize: 14, color: "#7c8a9e", margin: 0, maxWidth: 700, lineHeight: 1.6 } },
          "How digit recognition error on the MNIST benchmark fell from an 0.80% SVM baseline (LeCun et al. 1998) to near-perfect 0.09% (An et al. 2020), crossing estimated human-level performance (≈0.20%) in 2011. Each milestone card links to its primary source.")
      ),

      // Chart
      e('div', {
        style: {
          maxWidth: 900, margin: "0 auto 36px", background: "#0f1323",
          borderRadius: 16, border: "1px solid rgba(255,255,255,0.06)", padding: "28px 20px 12px",
        },
      },
        e(ResponsiveContainer, { width: "100%", height: 380 },
          e(LineChart, { data: chartData, margin: { top: 30, right: 40, bottom: 20, left: 20 } },
            e(CartesianGrid, { strokeDasharray: "3 3", stroke: "rgba(255,255,255,0.06)" }),
            e(XAxis, {
              dataKey: "year", tick: { fill: "#7c8a9e", fontSize: 12 },
              axisLine: { stroke: "#333" }, tickLine: { stroke: "#333" },
              domain: [1996, 2023], type: "number",
              tickFormatter: function(v) { return v; },
              ticks: [1998, 2003, 2006, 2010, 2011, 2020],
            }),
            e(YAxis, {
              tick: { fill: "#7c8a9e", fontSize: 12 },
              axisLine: { stroke: "#333" }, tickLine: { stroke: "#333" },
              domain: [0, 1.0],
              tickFormatter: function(v) { return v + "%"; },
              label: { value: "Test Error Rate (%)", angle: -90, position: "insideLeft", offset: -5, style: { fill: "#7c8a9e", fontSize: 12 } },
            }),
            e(RechartsTooltip, { content: CustomTooltip }),
            e(ReferenceLine, {
              y: humanError, stroke: "#ef4444", strokeDasharray: "6 4", strokeWidth: 1.5,
              label: { value: "≈ Human level (0.2%)", position: "right", fill: "#ef4444", fontSize: 12, fontWeight: 600 },
            }),
            e(Line, {
              type: "monotone", dataKey: "error", stroke: "#38bdf8", strokeWidth: 3,
              dot: e(CustomDot, null),
              activeDot: { r: 10, stroke: "#38bdf8", strokeWidth: 3, fill: "#fff" },
              connectNulls: true,
            }),
            e(ReferenceDot, {
              x: 2006, y: 1.20, r: 0,
              label: { value: "← DBN (1.2%, no deformations)", position: "right", fill: "#f59e0b", fontSize: 12, fontWeight: 500 },
            })
          )
        ),
        e('div', { style: { textAlign: "center", fontSize: 12, color: "#7c8a9e", marginTop: 4 } },
          "Hover or tap data points for details. The dashed red line marks approximate human-level performance.")
      ),

      // Milestone cards
      e('div', { style: { maxWidth: 900, margin: "0 auto" } },
        e('h2', { style: { fontSize: 16, fontWeight: 700, color: "#fff", margin: "0 0 16px", letterSpacing: "-0.01em" } },
          "Milestone Details"),
        e('div', { style: { display: "flex", flexDirection: "column", gap: 12 } },
          ...milestones.map(function(m, i) {
            const isOpen = selected === i;
            return e('div', {
              key: i,
              onClick: function() { setSelected(isOpen ? null : i); },
              style: {
                background: isOpen ? "rgba(255,255,255,0.06)" : "rgba(255,255,255,0.02)",
                border: "1px solid " + (isOpen ? m.color + "66" : "rgba(255,255,255,0.06)"),
                borderRadius: 12, padding: "16px 20px", cursor: "pointer", transition: "all 0.2s ease",
              },
            },
              e('div', { style: { display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" } },
                e('div', { style: { width: 10, height: 10, borderRadius: "50%", background: m.color, flexShrink: 0 } }),
                e('span', { style: { fontWeight: 700, color: "#fff", fontSize: 15 } }, Math.floor(m.year)),
                e('span', { style: { color: "#aab4c4", fontSize: 14 } }, m.label),
                m.error !== null && e('span', {
                  style: { marginLeft: "auto", background: m.color + "22", color: m.color, padding: "2px 10px", borderRadius: 20, fontSize: 13, fontWeight: 700 },
                }, m.error + "%"),
                m.isOrigin && e('span', {
                  style: { marginLeft: "auto", background: "rgba(56,189,248,0.10)", color: "#38bdf8", padding: "2px 10px", borderRadius: 20, fontSize: 12, fontWeight: 600 },
                }, "Origin")
              ),
              isOpen && e('div', {
                style: { marginTop: 14, paddingTop: 12, borderTop: "1px solid rgba(255,255,255,0.08)" },
              },
                e('div', { style: { fontSize: 12, color: "#7c8a9e", marginBottom: 6, fontWeight: 600 } }, m.method),
                e('p', { style: { fontSize: 13, color: "#aab4c4", margin: "0 0 12px", lineHeight: 1.65 } }, m.detail),
                e('a', {
                  href: m.sourceUrl,
                  target: "_blank", rel: "noopener noreferrer",
                  onClick: function(ev) { ev.stopPropagation(); },
                  style: {
                    display: "inline-flex", alignItems: "center", gap: 6, fontSize: 12,
                    color: m.color, textDecoration: "none", fontWeight: 600,
                    background: m.color + "11", padding: "6px 14px", borderRadius: 8,
                    border: "1px solid " + m.color + "33",
                  },
                }, m.sourceLabel + " →")
              )
            );
          })
        )
      ),

      // Key insight
      e('div', {
        style: {
          maxWidth: 900, margin: "36px auto 0",
          background: "rgba(56, 189, 248, 0.06)", border: "1px solid rgba(56,189,248,0.15)",
          borderRadius: 12, padding: "20px 24px",
        },
      },
        e('p', { style: { fontSize: 13, color: "#aab4c4", margin: 0, lineHeight: 1.7 } },
          "Starting from an 0.80% SVM baseline in 1998, the MNIST error rate stagnated near 0.4% for almost a decade (2003–2010). The breakthrough to human-level performance came primarily from GPU acceleration enabling deeper networks and larger ensembles — not fundamentally new algorithms. Post-2011, advances in regularisation (DropConnect, 2013) and attention mechanisms (SE-Networks, 2020) pushed error well below human level. By 2020 an ensemble of just three CNNs reached 0.09%, limited mainly by the dataset’s own known mislabelled test images."
        )
      ),

      // Footer
      e('div', { style: { maxWidth: 900, margin: "24px auto 0", textAlign: "center", lineHeight: 2 } },
        e('span', { style: { fontSize: 11, color: "#7c8a9e" } }, "Sources: "),
        e('a', {
          href: "https://arxiv.org/abs/1404.7828",
          target: "_blank", rel: "noopener noreferrer",
          style: { fontSize: 11, color: "#7c8a9e", textDecoration: "underline", textUnderlineOffset: "3px" },
        }, "Schmidhuber (2014) arXiv:1404.7828"),
        e('span', { style: { fontSize: 11, color: "#7c8a9e" } }, " · "),
        e('a', {
          href: "https://doi.org/10.1109/5.726791",
          target: "_blank", rel: "noopener noreferrer",
          style: { fontSize: 11, color: "#7c8a9e", textDecoration: "underline", textUnderlineOffset: "3px" },
        }, "LeCun et al. (1998) IEEE"),
        e('span', { style: { fontSize: 11, color: "#7c8a9e" } }, " · "),
        e('a', {
          href: "https://arxiv.org/abs/1202.2745",
          target: "_blank", rel: "noopener noreferrer",
          style: { fontSize: 11, color: "#7c8a9e", textDecoration: "underline", textUnderlineOffset: "3px" },
        }, "Ciresan et al. (2012) arXiv:1202.2745"),
        e('span', { style: { fontSize: 11, color: "#7c8a9e" } }, " · "),
        e('a', {
          href: "https://arxiv.org/abs/2008.10400",
          target: "_blank", rel: "noopener noreferrer",
          style: { fontSize: 11, color: "#7c8a9e", textDecoration: "underline", textUnderlineOffset: "3px" },
        }, "An et al. (2020) arXiv:2008.10400"),
        e('span', { style: { fontSize: 11, color: "#7c8a9e" } }, " · ")
      ),
    );
  }

  ReactDOM.createRoot(document.getElementById('dashboard-root')).render(e(MNISTDashboard, null));
})();
