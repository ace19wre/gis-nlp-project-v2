// Lilaq versions of the four data figures in the paper. Data comes from the CSV
// files in data/, copied from the benchmark and weight-study results (read only).
// No font is set here, so the figures inherit the paper's text font.
#import "@preview/lilaq:0.5.0" as lq

#let c-blue = rgb("#2878d8")
#let c-orange = rgb("#ee6a35")
#let c-light = rgb("#a6c8f2")
#let c-green = rgb("#1aa07a")
#let c-amber = rgb("#f0a30a")
#let c-pink = rgb("#e377a8")
#let c-grid = luma(228)
#let c-ink = luma(70)

// Shared look: small text, light grid, no mirrored top/right axes.
#let _look(body, grid-x: false) = {
  set text(size: 7.5pt, fill: c-ink)
  show: lq.set-spine(stroke: 0.6pt + luma(130))
  show: lq.set-grid(stroke: 0.5pt + c-grid)
  if not grid-x { show: lq.cond-set(lq.grid.with(kind: "x"), stroke: none) }
  body
}

#let axes-base = (mirror: false, subticks: none)

// Two decimals, e.g. 0.9 -> "0.90".
#let fmt2(v) = {
  let s = str(calc.round(v, digits: 2))
  if s.len() == 3 { s + "0" } else { s }
}

#let swatch(col) = box(width: 7pt, height: 7pt, fill: col, baseline: 1pt)

// Exact-match accuracy per question category, full engine vs first attempt only.
#let fig-category(w: 6.9cm, h: 4.1cm) = _look({
  let d = csv("data/bench_by_category.csv").slice(1)
  let cats = d.map(r => upper(r.at(0).at(0)) + r.at(0).slice(1))
  let full = d.map(r => float(r.at(2)))
  let norep = d.map(r => float(r.at(3)))
  let xs = range(cats.len())
  align(center, stack(dir: ttb, spacing: 4pt,
    [#swatch(c-blue) Full engine #box(width: 12pt) #swatch(c-orange) No repair],
  lq.diagram(
    width: w, height: h,
    ylim: (0, 104),
    ylabel: [Exact match (% of questions)],
    yaxis: (..axes-base, ticks: range(0, 101, step: 20).map(v => (v, str(v)))),
    xaxis: (..axes-base, ticks: xs.map(i => (i, rotate(20deg, origin: top + right, reflow: true, cats.at(i))))),
    legend: none,
    lq.bar(xs.map(i => i - 0.2), full, width: 0.38, fill: c-blue),
    lq.bar(xs.map(i => i + 0.2), norep, width: 0.38, fill: c-orange),
  )))
})

// Grounding of the direct-LLM baseline next to the engine's geometry F1.
#let fig-baseline(w: 7.15cm, h: 4.1cm) = _look({
  let rows = csv("data/bench_summary.csv")
  let col(name) = rows.first().position(c => c == name)
  let get(cfg, name) = float(rows.slice(1).find(r => r.at(0) == cfg).at(col(name)))
  let vals = (
    get("direct_llm", "name_grounded"),
    get("direct_llm", "coord_grounded"),
    get("direct_llm", "precision_gold"),
    get("full", "f1"),
  ).map(v => v * 100)
  let labels = ([Names in\ the DB], [Near a real\ feature], [Near a gold\ feature], [Engine\ F1 vs gold])
  let xs = range(4)
  lq.diagram(
    width: w, height: h,
    ylim: (0, 108),
    ylabel: [%],
    yaxis: (..axes-base, ticks: range(0, 101, step: 20).map(v => (v, str(v)))),
    xaxis: (..axes-base, ticks: xs.map(i => (i, labels.at(i)))),
    lq.bar(xs, vals, width: 0.62, fill: (c-orange, c-orange, c-orange, c-blue)),
    ..xs.map(i => lq.place(i, vals.at(i) + 2, [#calc.round(vals.at(i))%], align: bottom)),
  )
})

// Rank agreement (Kendall tau) of each weighting scheme with the hand-picked weights.
#let fig-tau(w: 6.45cm, h: 4.8cm) = _look(grid-x: true, {
  let d = csv("data/weight_rank_agreement.csv").slice(1).filter(r => r.at(0) != "Baseline (hand-picked)")
  let rename = (
    "Scenario: Student": "Scenario Student",
    "Scenario: Premium": "Scenario Premium",
    "Scenario: Budget": "Scenario Budget",
    "TOPSIS (baseline w)": "TOPSIS",
  )
  let items = d.map(r => (
    name: rename.at(r.at(0), default: r.at(0)),
    top5: int(r.at(1)),
    tau: float(r.at(3)),
  )).sorted(key: it => -it.tau)
  let n = items.len()
  let ys = range(n).map(i => n - 1 - i)
  let kind(it) = if it.tau <= 0 { 2 } else if it.top5 == 5 { 0 } else { 1 }
  let pick(k) = (
    x: items.filter(it => kind(it) == k).map(it => it.tau),
    y: items.enumerate().filter(((i, it)) => kind(it) == k).map(((i, it)) => n - 1 - i),
  )
  let a = pick(0)
  let b = pick(1)
  let c = pick(2)
  lq.diagram(
    width: w, height: h,
    xlim: (-0.2, 1.45), ylim: (-0.6, n - 0.4),
    xlabel: [Kendall's $tau$ vs hand-picked weights (top-5 overlap)],
    xaxis: (..axes-base, ticks: range(-1, 7).map(i => (i * 0.2, str(calc.round(i * 0.2, digits: 1))))),
    yaxis: (..axes-base, ticks: items.enumerate().map(((i, it)) => (n - 1 - i, it.name)), subticks: none),
    legend: (position: bottom + right, dy: -2pt, stroke: none, fill: none),
    lq.vlines(0, stroke: 0.6pt + luma(130)),
    lq.hbar(a.x, a.y, width: 0.62, fill: c-blue, label: [Same top 5]),
    lq.hbar(b.x, b.y, width: 0.62, fill: c-light, label: [Top 5 partly differs]),
    lq.hbar(c.x, c.y, width: 0.62, fill: c-orange, label: [No rank agreement]),
    ..items.enumerate().map(((i, it)) => lq.place(
      calc.max(it.tau, 0) + 0.02, n - 1 - i,
      [#calc.round(it.tau, digits: 2) (#it.top5/5)],
      align: left + horizon,
    )),
  )
})

// One-at-a-time sensitivity of the ranking to each criterion's weight.
#let fig-oat(w: 7.35cm, h: 4.3cm) = _look(grid-x: true, {
  let d = csv("data/weight_oat_sensitivity.csv").slice(1)
  let crits = (
    ("footfall", c-blue), ("youth", c-orange), ("access", c-green),
    ("rent", c-amber), ("competition", c-pink),
  )
  lq.diagram(
    width: w, height: h,
    xlim: (-32, 32), ylim: (0.9, 0.995),
    xlabel: [Change in one criterion's weight (%)],
    ylabel: [Kendall's $tau$ vs hand-picked ranking],
    xaxis: (..axes-base, ticks: range(-30, 31, step: 10).map(v => (v, [#v]))),
    yaxis: (..axes-base, ticks: (0.90, 0.92, 0.94, 0.96, 0.98).map(v => (v, fmt2(v)))),
    legend: (position: bottom + center, dx: 20pt, dy: -2pt, stroke: none, fill: none),
    lq.vlines(0, stroke: 0.6pt + luma(130)),
    ..crits.map(((name, col)) => {
      let rs = d.filter(r => r.at(0) == name)
      lq.plot(
        rs.map(r => float(r.at(1))), rs.map(r => float(r.at(2))),
        color: col, stroke: 1pt + col, mark: "o", mark-size: 3.2pt, label: name,
      )
    }),
  )
})
