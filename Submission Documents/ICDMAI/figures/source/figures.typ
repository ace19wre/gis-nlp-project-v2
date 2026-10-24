// All figures of the ICDMAI paper that are drawn in code, one per page.
// Export (from this folder):
//   typst compile --format svg figures.typ ../fig-{0p}.svg
//   typst compile --format png --ppi 300 figures.typ ../fig-{0p}.png
#import "plots.typ": fig-category, fig-baseline, fig-tau, fig-oat
#import "@preview/fletcher:0.5.8" as fletcher: node, edge

#set page(width: auto, height: auto, margin: 5pt)
#set text(font: "Times New Roman", size: 10pt)

// Figure 1: architecture
#fletcher.diagram(
  node-stroke: 0.8pt,
  node-shape: rect,
  node-inset: 7pt,
  node-corner-radius: 3pt,
  spacing: (30mm, 20mm),
  node((0, 0), align(center)[*Web application*\ #text(size: 9pt)[React, MapLibre GL,\ Zustand]], name: <ui>),
  node((1, 0), align(center)[*FastAPI backend*\ #text(size: 9pt)[NL query and\ decision endpoints]], name: <api>),
  node((2, 0), align(center)[*LLM (hosted API)*\ #text(size: 9pt)[intent, SQL,\ explanation]], name: <llm>),
  node((0, 1), align(center)[*Martin*\ #text(size: 9pt)[vector tiles]], name: <tiles>),
  node((1, 1), align(center)[*PostgreSQL + PostGIS*\ #text(size: 9pt)[spatial data,\ read-only role]], name: <db>),
  edge(<ui>, <api>, "<->", label: text(size: 8.5pt)[JSON, GeoJSON]),
  edge(<api>, <llm>, "<->", label: text(size: 8.5pt)[prompts]),
  edge(<api>, <db>, "->"),
  edge(<db>, <tiles>, "->"),
  edge(<tiles>, <ui>, "->", label: text(size: 8.5pt)[MVT tiles], label-side: left),
)

#pagebreak()

// Figure 2: query-engine pipeline
#fletcher.diagram(
  node-stroke: 0.8pt,
  node-shape: rect,
  node-inset: 6pt,
  node-corner-radius: 3pt,
  spacing: (26mm, 22mm),
  node((0, 0), [Question], name: <q>),
  node((1, 0), [Intent check], name: <intent>),
  node((2, 0), [SQL generation], name: <gen>),
  node((3, 0), [Validation], name: <val>),
  node((2, 1), [Execution\ (read-only role)], name: <exe>),
  node((1, 1), [GeoJSON layer\ and explanation], name: <res>),
  node((0, 1), [Map and\ answer panel], name: <map>, fill: rgb("#e8f5e9"), stroke: 0.8pt + rgb("#2e7d32")),
  edge(<q>, <intent>, "->"),
  edge(<intent>, <gen>, "->"),
  edge(<gen>, <val>, "->"),
  edge(<val>, <exe>, "->"),
  edge(<exe>, <res>, "->"),
  edge(<res>, <map>, "->"),
  edge(<exe>, <gen>, "-->", label: text(size: 8.5pt)[error or 0 rows], label-side: left),
)

#pagebreak()
#fig-category()
#pagebreak()
#fig-baseline()
#pagebreak()
#fig-tau()
#pagebreak()
#fig-oat()
