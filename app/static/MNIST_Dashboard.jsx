const { useState } = React;
const { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine, ReferenceDot } = Recharts;

const ARTICLE_URL = "https://arxiv.org/pdf/1404.7828";

const milestones = [
  {
    year: 1989,
    error: null,
    label: "MNIST Created",
    method: "CNN + BP (LeCun et al.)",
    detail: "Backpropagation applied to convolutional neural layers; MNIST dataset introduced. Became 'perhaps the most famous benchmark of Machine Learning.'",
    color: "#38bdf8",
    isOrigin: true,
  },
  {
    year: 2003,
    error: 0.40,
    label: "CNN + Distortions",
    method: "CNN + elastic deformations (Simard et al.)",
    detail: "BP-trained CNN set record of 0.40% using training pattern deformations but no unsupervised pre-training. Standard BP net achieved 0.70%.",
    color: "#0ea5e9",
  },
  {
    year: 2006,
    error: 1.20,
    label: "Deep Belief Network",
    method: "DBN + BP fine-tuning (Hinton & Salakhutdinov)",
    detail: "DBN achieved 1.2% without deformations. Demonstrated unsupervised pre-training can help deep nets; coined the term 'Deep Learning.'",
    color: "#f59e0b",
    isDBN: true,
  },
  {
    year: 2006.3,
    error: 0.39,
    label: "Improved CNN",
    method: "CNN + deformations (Ranzato et al.)",
    detail: "New MNIST record of 0.39%. Same year saw the first GPU-based CNN implementation (4× faster than CPU).",
    color: "#0ea5e9",
  },
  {
    year: 2010,
    error: 0.35,
    label: "GPU + Plain BP",
    method: "Standard deep NN + BP on GPU (Ciresan et al.)",
    detail: "Record 0.35% using plain backprop on GPU (50× faster than CPU). No convolution, no unsupervised pre-training. 'Hardware advances more important than algorithms.'",
    color: "#10b981",
  },
  {
    year: 2011,
    error: 0.20,
    label: "GPU-MPCNN Ensemble",
    method: "Multi-Column GPU-MPCNN (Ciresan et al.)",
    detail: "First human-competitive performance (~0.2%) on MNIST. 'A dramatic improvement, since the record had hovered around 0.4% for almost a decade.' Same architecture achieved first superhuman result on traffic signs.",
    color: "#ef4444",
  },
];

const chartData = milestones
  .filter((m) => m.error !== null)
  .map((m) => ({
    year: Math.floor(m.year),
    error: m.error,
    label: m.label,
    page: m.page,
    section: m.section,
  }));

const humanError = 0.20;

function CustomDot({ cx, cy, payload }) {
  const m = milestones.find(
    (mi) => Math.floor(mi.year) === payload.year && mi.error === payload.error
  );
  const fill = m ? m.color : "#38bdf8";
  return (
    <circle
      cx={cx}
      cy={cy}
      r={7}
      fill={fill}
      stroke="#fff"
      strokeWidth={2}
      style={{ filter: "drop-shadow(0 1px 3px rgba(0,0,0,0.3))" }}
    />
  );
}

function CustomTooltip({ active, payload }) {
  if (!active || !payload || !payload.length) return null;
  const d = payload[0].payload;
  const m = milestones.find(
    (mi) => Math.floor(mi.year) === d.year && mi.error === d.error
  );
  if (!m) return null;
  return (
    <div
      style={{
        background: "#0c0f1a",
        border: `2px solid ${m.color}`,
        borderRadius: 10,
        padding: "14px 18px",
        maxWidth: 320,
        color: "#e8edf5",
        fontSize: 13,
        lineHeight: 1.5,
        boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
        fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
      }}
    >
      <div style={{ fontWeight: 700, fontSize: 15, color: "#fff", marginBottom: 4 }}>
        {m.label} ({Math.floor(m.year)})
      </div>
      <div style={{ color: m.color, fontWeight: 600, marginBottom: 6 }}>
        Error: {m.error}%
      </div>
      <div style={{ fontSize: 12, color: "#7c8a9e", marginBottom: 8 }}>{m.method}</div>
      <div style={{ fontSize: 12, color: "#aab4c4" }}>{m.detail}</div>
    </div>
  );
}

function MNISTDashboard() {
  const [selected, setSelected] = useState(null);

  return (
    <div
      style={{
        color: "#e8edf5",
        fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
        width: "100%",
      }}
    >
      {/* Header */}
      <div style={{ maxWidth: 900, margin: "0 auto 32px" }}>
        <h1
          style={{
            fontSize: 28,
            fontWeight: 800,
            color: "#fff",
            margin: "0 0 8px",
            lineHeight: 1.2,
          }}
        >
          MNIST Error Rate Milestones
        </h1>
        <p style={{ fontSize: 14, color: "#7c8a9e", margin: 0, maxWidth: 650, lineHeight: 1.6 }}>
          How digit recognition error on the MNIST benchmark dropped from 0.40% to human-competitive
          0.20% between 2003 and 2011.
        </p>
      </div>

      {/* Chart */}
      <div
        style={{
          maxWidth: 900,
          margin: "0 auto 36px",
          background: "#0f1323",
          borderRadius: 16,
          border: "1px solid rgba(255,255,255,0.06)",
          padding: "28px 20px 12px",
        }}
      >
        <ResponsiveContainer width="100%" height={380}>
          <LineChart data={chartData} margin={{ top: 30, right: 40, bottom: 20, left: 20 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
            <XAxis
              dataKey="year"
              tick={{ fill: "#7c8a9e", fontSize: 12 }}
              axisLine={{ stroke: "#333" }}
              tickLine={{ stroke: "#333" }}
              domain={[2002, 2012]}
              type="number"
              tickFormatter={(v) => v}
              ticks={[2003, 2005, 2006, 2008, 2010, 2011]}
            />
            <YAxis
              tick={{ fill: "#7c8a9e", fontSize: 12 }}
              axisLine={{ stroke: "#333" }}
              tickLine={{ stroke: "#333" }}
              domain={[0, 1.4]}
              tickFormatter={(v) => `${v}%`}
              label={{
                value: "Test Error Rate (%)",
                angle: -90,
                position: "insideLeft",
                offset: -5,
                style: { fill: "#7c8a9e", fontSize: 11 },
              }}
            />
            <Tooltip content={<CustomTooltip />} />
            <ReferenceLine
              y={humanError}
              stroke="#ef4444"
              strokeDasharray="6 4"
              strokeWidth={1.5}
              label={{
                value: "≈ Human level (0.2%)",
                position: "right",
                fill: "#ef4444",
                fontSize: 11,
                fontWeight: 600,
              }}
            />
            <Line
              type="monotone"
              dataKey="error"
              stroke="#38bdf8"
              strokeWidth={3}
              dot={<CustomDot />}
              activeDot={{ r: 10, stroke: "#38bdf8", strokeWidth: 3, fill: "#fff" }}
              connectNulls
            />
            {/* DBN point — shown separately as it's off the main record line */}
            <ReferenceDot
              x={2006}
              y={1.20}
              r={0}
              label={{
                value: "← DBN (1.2%, no deformations)",
                position: "right",
                fill: "#f59e0b",
                fontSize: 10,
                fontWeight: 500,
              }}
            />
          </LineChart>
        </ResponsiveContainer>
        <div style={{ textAlign: "center", fontSize: 12, color: "#7c8a9e", marginTop: 4 }}>
          Hover or tap data points for details. The dashed red line marks approximate human-level performance.
        </div>
      </div>

      {/* Milestone cards */}
      <div style={{ maxWidth: 900, margin: "0 auto" }}>
        <h2
          style={{
            fontSize: 16,
            fontWeight: 700,
            color: "#fff",
            margin: "0 0 16px",
            letterSpacing: "-0.01em",
          }}
        >
          Milestone Details
        </h2>
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {milestones.map((m, i) => {
            const isOpen = selected === i;
            return (
              <div
                key={i}
                onClick={() => setSelected(isOpen ? null : i)}
                style={{
                  background: isOpen ? "rgba(255,255,255,0.06)" : "rgba(255,255,255,0.02)",
                  border: `1px solid ${isOpen ? m.color + "66" : "rgba(255,255,255,0.06)"}`,
                  borderRadius: 12,
                  padding: "16px 20px",
                  cursor: "pointer",
                  transition: "all 0.2s ease",
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap" }}>
                  <div
                    style={{
                      width: 10,
                      height: 10,
                      borderRadius: "50%",
                      background: m.color,
                      flexShrink: 0,
                    }}
                  />
                  <span style={{ fontWeight: 700, color: "#fff", fontSize: 15 }}>
                    {Math.floor(m.year)}
                  </span>
                  <span style={{ color: "#aab4c4", fontSize: 14 }}>{m.label}</span>
                  {m.error !== null && (
                    <span
                      style={{
                        marginLeft: "auto",
                        background: m.color + "22",
                        color: m.color,
                        padding: "2px 10px",
                        borderRadius: 20,
                        fontSize: 13,
                        fontWeight: 700,
                      }}
                    >
                      {m.error}%
                    </span>
                  )}
                  {m.isOrigin && (
                    <span
                      style={{
                        marginLeft: "auto",
                        background: "rgba(56,189,248,0.10)",
                        color: "#38bdf8",
                        padding: "2px 10px",
                        borderRadius: 20,
                        fontSize: 12,
                        fontWeight: 600,
                      }}
                    >
                      Origin
                    </span>
                  )}
                </div>
                {isOpen && (
                  <div style={{ marginTop: 14, paddingTop: 12, borderTop: "1px solid rgba(255,255,255,0.08)" }}>
                    <div style={{ fontSize: 12, color: "#7c8a9e", marginBottom: 6, fontWeight: 600 }}>
                      {m.method}
                    </div>
                    <p style={{ fontSize: 13, color: "#aab4c4", margin: "0 0 12px", lineHeight: 1.65 }}>
                      {m.detail}
                    </p>
                    <a
                      href={`${ARTICLE_URL}#page=${m.page}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      onClick={(e) => e.stopPropagation()}
                      style={{
                        display: "inline-flex",
                        alignItems: "center",
                        gap: 6,
                        fontSize: 12,
                        color: m.color,
                        textDecoration: "none",
                        fontWeight: 600,
                        background: m.color + "11",
                        padding: "6px 14px",
                        borderRadius: 8,
                        border: `1px solid ${m.color}33`,
                      }}
                    >
                      📄 Open in Article →
                    </a>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {/* Key insight */}
      <div
        style={{
          maxWidth: 900,
          margin: "36px auto 0",
          background: "rgba(56, 189, 248, 0.06)",
          border: "1px solid rgba(56,189,248,0.15)",
          borderRadius: 12,
          padding: "20px 24px",
        }}
      >
        <p style={{ fontSize: 13, color: "#aab4c4", margin: 0, lineHeight: 1.7 }}>
            The MNIST error rate stagnated near 0.4% for almost a decade (2003–2010). The breakthrough to
            human-level performance came not from fundamentally new algorithms, but from GPU acceleration
            that made it practical to train deeper networks and larger ensembles. As Schmidhuber writes :
            "advances in exploiting modern computing hardware were more important than advances in algorithms."
        </p>
      </div>

      {/* Footer */}
      <div style={{ maxWidth: 900, margin: "24px auto 0", textAlign: "center" }}>
        <p style={{ fontSize: 11, color: "#7c8a9e" }}>
          Data source: Schmidhuber, J. (2014). "Deep Learning in Neural Networks: An Overview."
          arXiv:1404.7828v4
        </p>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('dashboard-root')).render(<MNISTDashboard />);
