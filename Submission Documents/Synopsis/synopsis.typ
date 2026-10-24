// One-page synopsis: abstract, objective, implementation and application.
// Compile from this folder:
//   typst compile --font-path "../Black Book Report/template/fonts" synopsis.typ synopsis.pdf
#import "@preview/fletcher:0.5.8" as fletcher: node, edge

#let accent = rgb("#B7202E")

#set page(paper: "a4", margin: 1cm)
#set text(font: "Times New Roman", size: 11.5pt)
#set par(justify: true, leading: 0.55em, spacing: 0.7em)
#set list(indent: 0.4em, body-indent: 0.5em, spacing: 0.4em)

#let heading-bar(title) = {
  v(0.35em)
  text(weight: "bold", size: 11.5pt, fill: accent)[#upper(title)]
  v(-0.5em)
  line(length: 100%, stroke: 0.6pt + accent)
  v(-0.15em)
}

// ---- letterhead
#grid(
  columns: (2cm, 1fr, 2cm),
  align: horizon,
  image("SV.svg", height: 1.7cm),
  align(center)[
    #text(size: 13pt, weight: "bold", fill: accent)[K.J. SOMAIYA INSTITUTE OF TECHNOLOGY]\
    #text(size: 10.5pt, fill: accent)[Department of Artificial Intelligence and Data Science]
  ],
  align(right, image("UOM.svg", height: 1.7cm)),
)
#v(-0.2em)
#line(length: 100%, stroke: 1.4pt + accent)

#align(center)[
  #v(0.1em)
  #text(size: 10pt, weight: "bold", tracking: 0.08em)[PROJECT SYNOPSIS]\
  #v(0.1em)
  #text(size: 14.5pt, weight: "bold")[Geospatial Query System with Natural Language\ Processing and GIS Integration]
  #v(0.15em)
  Riddhesh Chaudhary, Arpit Balmiki, Chirayu Vyas #h(0.8em) | #h(0.8em) Guide: Dr. Vaishali Wadhe
]

// ---- abstract
#heading-bar("Abstract")
Choosing where to open a business, or judging whether a neighbourhood is safe, connected and affordable, normally takes weeks of manual surveys across maps, listings and reports. Large language models (LLMs) could make spatial analysis accessible, but answering directly they invent place names and coordinates, and nothing can be verified. This project lets a user ask a spatial question in plain English. An LLM pipeline writes a PostGIS query against a documented database schema, the query is validated and run on real data under a read-only role, and the result is returned as an interactive map layer with a short explanation and the exact SQL, so every answer can be checked. On a benchmark of 39 spatial questions the engine returns exactly the expected answer for 74.4% of them (geometry F1 88.4%), whereas a direct-LLM baseline names places that exist in the database only 19.5% of the time.

// ---- objective
#heading-bar("Objective")
The aim is a natural-language geospatial query and decision-support system whose answers are computed from real data.
- Let users ask spatial questions in plain English, without SQL or GIS knowledge.
- Translate each question into a validated PostGIS query and return a map layer, an explanation and the SQL that produced it.
- Build a reusable spatial database from open data (OpenStreetMap, property listings, area safety scores) that can be loaded for any city.
- Support location decisions: site report, competition analysis, cost-to-open estimate and comparison of candidate locations.
- Keep results explainable and keep measured values clearly separate from modelled estimates.

// ---- implementation
#heading-bar("Implementation")
Three layers: a React and MapLibre GL web workspace, a FastAPI backend that calls the LLM (Groq, `openai/gpt-oss-120b`) through one client module, and a PostgreSQL 16 + PostGIS 3.4 database that Martin publishes as vector tiles.

#align(center)[
  #fletcher.diagram(
    node-stroke: 0.7pt,
    node-shape: rect,
    node-inset: 4pt,
    node-corner-radius: 2pt,
    spacing: (6.2mm, 5mm),
    node-fill: rgb("#f7f7f7"),
    node((0, 0), text(size: 8.5pt)[Question in\ English]),
    edge("->"),
    node((1, 0), text(size: 8.5pt)[Intent\ check]),
    edge("->"),
    node((2, 0), text(size: 8.5pt)[Schema-grounded\ SQL generation]),
    edge("->"),
    node((3, 0), text(size: 8.5pt)[Validation, read-only\ execution, repair]),
    edge("->"),
    node((4, 0), text(size: 8.5pt)[GeoJSON layer +\ explanation + SQL]),
    edge("->"),
    node((5, 0), text(size: 8.5pt)[Map\ answer], fill: rgb("#e8f5e9"), stroke: 0.7pt + rgb("#2e7d32")),
  )
]

- *Query engine.* The model sees a compact schema description, so it can only reference data that exists. The SQL must be a single `SELECT`, runs under a read-only role with a 15 s timeout, and is retried with the error fed back (at most two repairs, plus one loosening for an empty result).
- *Data.* A loader driven by a city polygon (OSMnx) fills the database. Mumbai holds 48 boundaries, 16.8k road segments, 2.2k transit stops, 10.8k businesses and points of interest, 76,000 property listings and safety scores for 40 neighbourhoods.
- *Decision tools.* Site report, competition and catchment analysis (with suggested lower-competition spots), cost-to-open and break-even estimator, and a comparison of up to three locations. Counts, distances and prices are measured; rent, revenue and payback are modelled and labelled as estimates.
- *Evaluation.* A benchmark of 39 questions with hand-written gold SQL (six categories) and a sensitivity study of the earlier weighted-sum ranking.

// ---- application
#heading-bar("Application")
- *Business site selection:* a prospective cafe or pharmacy owner can compare locations on competition, demand, transit access and start-up cost in one place.
- *Property decisions:* buyers and renters can weigh price per square foot, transit, amenities and the area safety score.
- *Urban and public-service analysis:* questions such as "hospitals within 1 km of a metro station" show access to services without GIS tools.
- *Research and teaching:* a checkable natural-language-to-SQL benchmark for spatial data, extendable to other cities.

#text(size: 9pt, style: "italic")[Current limits: the benchmark is small and was run once, only Mumbai is loaded, and cost and revenue figures are planning estimates, not financial advice.]
