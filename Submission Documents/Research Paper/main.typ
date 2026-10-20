#import "@preview/charged-ieee:0.1.4": ieee
#import "@preview/fletcher:0.5.8" as fletcher: node, edge
#import "lilaq/figs.typ": fig-category, fig-baseline, fig-tau, fig-oat

#show: ieee.with(
  title: [A Natural-Language Geospatial Query\ and Site-Evaluation System on PostGIS],
  abstract: [
    Geospatial analysis supports urban planning, retail strategy and infrastructure decisions, yet traditional GIS platforms demand expertise in spatial query languages and specialised software. Large language models (LLMs) can lower this barrier, but systems that let the model answer directly tend to hallucinate place names and coordinates, which makes their output unverifiable. This paper presents GeoQuery, a Felt-style layered web map driven by a natural-language to PostGIS query engine grounded in open data. A user asks a spatial question in English, for example "hospitals within 1 km of a metro station". An LLM writes a PostGIS query against a documented schema, the query is executed on real data, and the system returns a GeoJSON answer layer, a grounded explanation and the SQL itself, so every answer carries provenance. On top of the engine we build intelligent decision tools: a click-to-evaluate site report, a competition and catchment analysis, a cost-to-open and break-even estimator, and a side-by-side comparison of up to three candidate locations. The system runs on PostgreSQL 16 with PostGIS 3.4, serves vector tiles with Martin, and renders them with MapLibre GL. It is loaded with Mumbai data from OpenStreetMap, a 76,000-row house-price dataset and area-level crime data, and its ETL is designed to generalise to other cities. We describe the architecture, the decision models and their current limitations, and report a first benchmark of query accuracy on 39 spatial questions.
  ],
  authors: (
    
    (
      name: "Dr. Vaishali Wadhe",
      department: [Department of Artificial Intelligence & Data Science],
      organization: [K.J. Somaiya Institute of Technology],
      location: [Mumbai, India],
      email: "vwadhe@somaiya.edu"
    ),
    (
      name: "Riddhesh Chaudhary",
      department: [Department of Artificial Intelligence & Data Science],
      organization: [K.J. Somaiya Institute of Technology],
      location: [Mumbai, India],
      email: "riddhesh.c@somaiya.edu"
    ),
    (
      name: "Arpit Balmiki",
      department: [Department of Artificial Intelligence & Data Science],
      organization: [K.J. Somaiya Institute of Technology],
      location: [Mumbai, India],
      email: "arpit.b@somaiya.edu"
    ),
    (
      name: "Chirayu Vyas",
      department: [Department of Artificial Intelligence & Data Science],
      organization: [K.J. Somaiya Institute of Technology],
      location: [Mumbai, India],
      email: "chirayu.vyas@somaiya.edu"
    ),
  ),
  index-terms: ("Generative AI", "GIS", "Natural Language Processing", "Text-to-SQL", "Spatial SQL", "PostGIS", "Site Selection"),
)

= Introduction
Geospatial data is central to urban planning, transportation, environmental monitoring and retail analytics. Geographic Information Systems (GIS) have traditionally been the main tools for such analysis, but they require users to understand spatial data handling, query languages such as SQL, and specialised software. This creates a barrier for the many people who have location questions but no GIS training.

Web platforms such as Felt have made map creation, collaboration and visualization much easier @felt. Even so, users must still translate a real-world question into manual operations on layers and filters. At the same time, LLMs have made natural-language interfaces to structured data practical, and recent work applies them to spatial data @chatgeoai @spatialt2s.

A naive way to build such an interface is to let the LLM answer the question itself. Our first proof of concept (POC) did this and exposed three weaknesses. The model invented area names and coordinates. Ranking used a fixed hand-weighted formula over about 40 areas with synthetic 1 to 10 metrics. Map markers were placed with random coordinate jitter, and the maps were Leaflet raster maps with no real spatial computation. None of the outputs could be checked: the assistant answered with familiar area names, but nothing in the answer was computed from data.

The central idea of this work is to replace "the LLM hallucinates the answer" with "the LLM writes a structured spatial query that is executed on real data". Every output is then verifiable and reproducible, and the generated SQL is shown to the user as provenance.

GeoQuery implements this idea as a full-screen layered map with a natural-language query bar. Beyond exploratory queries, it supports decision-oriented work for prospective business owners: evaluating a clicked location, analysing local competition and catchment demand, estimating the cost to open a store, and comparing candidate sites. The main contributions are:

+ A natural-language to PostGIS query engine that grounds the LLM in a documented schema and returns a GeoJSON layer, an explanation and the executed SQL.
+ A real-data foundation: an ETL pipeline that loads OpenStreetMap, real-estate listings and crime data into a single spatial database, designed to work for any city.
+ A set of decision tools (site evaluation, competition analysis, cost-to-open, location comparison) built on the same data.
+ An honest account of what is and is not yet validated, together with the evaluation plan for the missing pieces.

= Literature Survey
Traditional GIS platforms such as ArcGIS and QGIS provide buffering, proximity analysis and spatial querying, but assume knowledge of spatial concepts, data formats and query languages. Cloud platforms such as Felt and Mapbox improve collaboration and visualization @felt, yet users still drive them through layers, filters and map controls.

Natural-language interfaces to databases map a question to an executable query. Benchmarks such as Spider @spider and BIRD @bird have driven progress on general text-to-SQL, with LLM-based systems now dominating. Spatial questions add difficulty: the model must pick the right geometry types, apply spatial predicates and distance functions correctly, and respect coordinate reference systems. Early geospatial interfaces used rule-based mapping from keywords such as "near" and "within" to spatial operations. These are effective for simple queries but brittle for ambiguous or compositional ones.

More recent work uses LLMs for geospatial tasks. A multi-agent spatial text-to-SQL pipeline reports that adding an execution-based review stage improves accuracy by roughly 11 points @spatialt2s. ChatGeoAI converts natural language into executable geospatial operations for non-expert users @chatgeoai. GeoLLM shows that LLMs combined with OpenStreetMap features can model quantities for which ground truth is scarce @geollm. We take the first two as the design reference for our query engine. The 11-point figure is a result from that work, not from ours. We treat GeoLLM as relevant to estimating metrics, such as rent, where no direct data exists.

Spatial decision support systems extend GIS with multi-criteria decision analysis (MCDA) for tasks such as site selection @malczewski. They rank candidates by combining normalised criteria with weights, but typically require expert configuration and expert interpretation of the result.

OpenStreetMap (OSM) provides free, globally available data on roads, amenities and land use @osm, and tools such as OSMnx make it easy to acquire polygon-bounded extracts for any city @osmnx. PostGIS adds spatial types, GiST indexing and spatial functions to PostgreSQL, which makes it a suitable execution target for generated queries.

Existing systems tend to cover either visualization, query processing or decision support. We combine all three on one open-data stack, with the emphasis on verifiable query results.

= Proposed System
GeoQuery lets users ask questions about geospatial data in plain English and then act on the results with decision tools. Its workspace is a full-screen map with a layer panel, a natural-language query bar, and panels for evaluating, comparing and costing locations.

@fig-system gives an overview. A question goes from the browser to the FastAPI backend, where an LLM pipeline checks its intent, grounds it in the schema and generates a PostGIS query. The query is validated and executed, a correction loop retries it on an error or an empty result, and the rows are returned as a GeoJSON answer layer drawn by MapLibre GL. The stages are detailed in the Methodology section.

#figure(
  placement: top,
  scope: "parent",
  fletcher.diagram(
    spacing: (12mm, 10mm),
    node-stroke: 0.8pt + rgb("#2c3e50"),
    node-fill: rgb("#f8f9fa"),

    // Row 1: left to right
    node((0, 0), align(center)[*User Input*\ #text(size: 8pt, fill: luma(100))[_(Natural Language)_]]),
    edge((0, 0), (1, 0), "->"),

    node((1, 0), align(center)[*FastAPI Backend*]),
    edge((1, 0), (2, 0), "->"),

    node((2, 0), align(center)[
      *LLM Pipeline*\
      #text(size: 7.5pt, fill: luma(80))[(Intent #sym.arrow.r Schema grounding #sym.arrow.r SQL)]
    ]),
    edge((2, 0), (3, 0), "->"),

    node((3, 0), align(center)[*PostGIS Database*\ *Execution*]),
    edge((3, 0), (3, 1), "->"),

    // Row 2: right to left
    node((3, 1), align(center)[*Validation/Correction*\ *Loop*]),
    edge((3, 1), (2, 1), "->"),

    node((2, 1), align(center)[*GeoJSON Generation*]),
    edge((2, 1), (1, 1), "->"),

    node((1, 1), align(center)[*MapLibre Rendering*\ #text(size: 8pt, fill: luma(100))[_(Answer Layer)_]], fill: rgb("#e8f5e9"), stroke: 0.8pt + rgb("#2e7d32")),
  ),
  caption: [System overview of GeoQuery: from a natural-language question to an answer layer on the map.],
) <fig-system>

== Problem Statement and Objectives

Geospatial analysis is essential for business planning, but existing GIS tools demand knowledge of spatial data and query languages and mostly leave users to interpret patterns by hand. A person deciding where to open a cafe must weigh prices, transit, safety, competition and start-up cost, and no single easy tool combines these. LLM interfaces lower the barrier, but when the model supplies the answer directly, place names and coordinates can be invented and nothing can be verified. A system is needed that accepts natural language, computes answers on real spatial data, shows how each answer was obtained, and supports practical location decisions.

The objective is therefore a natural-language geospatial query and decision-support system that accepts plain English, translates it into PostGIS queries through an LLM grounded in a documented schema, returns a map layer with an explanation and the executed SQL, and supports location decisions (site evaluation, competition and catchment analysis, cost-to-open and break-even estimation, and side-by-side comparison), using only open-source tools and open data.

== Methodology

The system is a modular pipeline. A question enters through the query bar, the backend turns it into a spatial query, the database executes it, and the frontend draws the answer. Decision tools reuse the same database through dedicated endpoints.

=== Explanation of Methodology

+ *User input.* The user types a spatial question, either exploratory ("hospitals within 1 km of a metro station") or decision-oriented.
+ *Intent check.* A first LLM call decides whether the question is a clear spatial query and labels its task type (filter, proximity, ranking, aggregation, site selection or other). If the target is genuinely unknowable, for example "best place?", the system returns a short follow-up question instead of running a query.
+ *Schema grounding.* The SQL-generating call receives a compact description of the queryable schema in its prompt: the tables and columns of the `admin`, `roads`, `transport`, `poi`, `realestate`, `demo`, `crime` and `env` schemas with geometry types and the allowed values of key categorical columns, plus rules to filter every table by `city_id`, never reference an unlisted table or column, and emit one read-only `SELECT` with a geometry column named `geom`. Because the model can only reference data that exists, it cannot invent places. The same description is stored as a 34-row `meta.schema_catalog` table, which the engine does not read at query time.
+ *Query generation.* The LLM (Groq `openai/gpt-oss-120b`, behind a single client module) writes a PostGIS query using functions such as `ST_DWithin` and `ST_Contains` over EPSG:4326 geometry indexed with GiST. The text is validated before execution: it must be a single `SELECT` or `WITH` statement with no chained statements and no data-modifying or DDL keywords.
+ *Execution.* The query runs on PostgreSQL 16 with PostGIS 3.4 as a dedicated `geo_readonly` role, with a 15 second statement timeout and a cap of 5,000 returned features.
+ *Repair.* If the query fails validation or raises a database error, the error text is fed back to the model for a corrected query, with at most two such repairs. If a valid query returns zero rows, the model is asked once to loosen it. The best successful attempt is kept, preferring a non-empty one, and every attempt is returned to the client. In total there are at most four generation attempts, a simplified form of the execution-based review in @spatialt2s; the effect of the repair stage on accuracy has not yet been measured.
+ *Result generation.* Rows are converted to a GeoJSON answer layer, and the LLM writes a short explanation grounded in a sample of the returned rows. The generated SQL is returned alongside, so users can inspect how the answer was obtained.
+ *Visualization.* The answer layer is drawn on the map next to the base layers. Base layers are served as Mapbox Vector Tiles by Martin directly from PostGIS.

== Decision Support Models
The decision tools are built on the same database and exposed as separate endpoints (`/site-eval`, `/competitor-analysis`, `/business-estimate`).

*Site evaluation.* For a clicked point and a radius between 0.5 and 3 km, the report gives the median price per sqft of nearby listings, a typical price band, a comparison with the city median, a breakdown by size band, the nearest metro, rail and bus stops, amenity counts (healthcare, education, food, banking, shopping), and a safety score with a risk level.

*Competition and catchment analysis.* The report gives the competitor count, density, nearest competitor, a saturation label and a 0 to 100 catchment demand index, and suggests lower-competition spots (green markers; competitors are red dots). Competitors are points in `poi.place` whose category matches the business type inside the chosen radius, and density is their count per km#super[2]. The saturation label uses fixed bands (below 5 low, 5 to 15 moderate, 15 to 30 high, above 30 saturated). The demand index counts points of interest in five groups (healthcare, education, food, banking and shopping) and transit stops inside the radius, caps each count (40, 25, 40, 15, 30 and 12 respectively) so that dense areas do not dominate, and combines them with business-specific weights, for example a cafe weights education, shopping and transit. To suggest gaps, a 5 by 5 grid of candidate spots is laid over the radius, each scored as its demand index divided by one plus its competitors within 500 m. Up to three spots with a demand index of at least 15 and a score at least 15% higher than the evaluated spot are suggested. The bands and weights are heuristics set by judgement and have not been calibrated against business outcomes.

*Cost-to-open and break-even.* The estimator takes a store area in sqft and returns one-time setup costs, monthly running costs, staff cost and working capital. Because rental data is not available, monthly rent per sqft is estimated as the median sale price per sqft of listings within 2.5 km times 0.5% (a rent-to-value ratio) and a commercial premium of 1.15, with a city default of 120 rupees per sqft if no listing is nearby. The security deposit is six months of rent and working capital is three months of running costs. Other line items are produced by the LLM, with a heuristic fallback. Customers per day are the store area (per 100 sqft) times a benchmark rate for the business type, a footfall multiplier of 0.6 to 1.5 from amenities within 1 km and metro or rail access within 800 m, and a competition factor $1 / (1 + 0.04 n)$ floored at 0.6, where $n$ is the number of competitors within 1 km. Revenue is customers times an average ticket (scaled by 0.8, 1.0 or 1.3 for economy, standard or premium tier) times 30 days; cost of goods is a fixed share of revenue, and profit is revenue minus cost of goods and the remaining monthly costs. The conservative, base and optimistic scenarios scale the customer count by 0.7, 1.0 and 1.3. Payback is the setup cost divided by monthly profit, and break-even revenue is the remaining monthly cost divided by one minus the cost-of-goods share. The per-type benchmarks are modelling assumptions set by the authors, not measured values, and because the LLM line items vary, two runs for the same site can give different totals, profit and payback.

*Location comparison.* Up to three pinned spots (A, B, C) are shown side by side across price, access, safety, competitors, rent, start-up cost, revenue, profit and payback. The best value in each row is marked.

*Area-level weighted ranking (legacy dashboard).* The original dashboard ranks areas with a standard weighted-sum MCDA model @malczewski. For area $i$ with criteria $m_(i k)$ (footfall, youth, access, rent and competition, each scored 0 to 10),

$ S_i = sum_(k=1)^K w_k thin m'_(i k), quad sum_(k=1)^K w_k = 1, $

where $m'_(i k) = m_(i k)$ for benefit criteria (footfall, youth, access) and $m'_(i k) = 10 - m_(i k)$ where lower is better (rent and competition). The hand-picked weights are 0.30, 0.25, 0.20, 0.15 and 0.10 in that order, and the five highest-scoring areas are returned. In the POC the metrics were synthetic.

To test how much the ranking depends on these weights we ran a sensitivity study on the 40 scored areas (script in the `eval/` folder). We compared the hand-picked weights with equal weights, rank-order centroid (ROC) weights, AHP weights (consistency ratio 0.011), entropy weights, CRITIC weights and three scenario weight sets (budget, student and premium), and we compared the weighted sum with TOPSIS under the baseline weights. Agreement with the baseline ranking was measured by Kendall's $tau$ and by the overlap of the top five areas. We also perturbed each weight by up to 30% one at a time, and drew 1,000 random weight vectors from a uniform Dirichlet distribution (seed 42) to see how often each area stays in the top five.

The ranking is stable under small changes to a single weight: the worst-case $tau$ for a 30% change in any one weight is 0.90 or higher (lowest for the access weight). It is not stable under a change of weighting scheme. AHP, ROC and the premium scenario keep the same top five as the baseline (Kendall $tau$ of 0.92, 0.81 and 0.83), while equal weights, entropy weights, the student scenario, the budget scenario, TOPSIS and CRITIC share only 2, 2, 2, 1, 1 and 0 of the baseline's top five areas ($tau$ of 0.41, 0.58, 0.87, -0.11, 0.36 and -0.01). Across random weight vectors the median $tau$ against the baseline is 0.33 (5th to 95th percentile: -0.49 to 0.84), and no area stays in the top five in more than 45% of draws (Andheri West is highest at 44.5%). The weights therefore encode a preference, not a neutral measurement, which is one reason the GeoQuery workspace uses measured spatial queries in place of this fixed ranking. These results describe the 40-area scored dataset and should not be read as evidence about real-world site quality.

== Implementation
GeoQuery has three layers: a presentation layer (React 19, Zustand and MapLibre GL), an application layer (FastAPI with the LLM client, and MongoDB for chat history only) and a data layer (PostgreSQL 16 with PostGIS 3.4, and Martin for vector tiles); @fig-stack lists the components. This separation keeps the model, the query execution and the rendering independently replaceable. The database holds all layers in EPSG:4326 with GiST indexes and a `city_id` on every row, so several cities can coexist. The ETL (`etl/`) ingests roads, transit, POIs and boundaries from OpenStreetMap by city polygon (OSMnx), geocodes 228 real-estate localities with Nominatim and loads the crime data, so the same pipeline can load other cities; the deployed instance is pre-loaded for Mumbai. In the workspace the left panel toggles vector layers (administrative boundaries, roads, transit stops, businesses and POIs, real-estate listings, and a crime and safety score), each with an opacity slider. Users can click a feature to inspect it, type a question into the query bar, or click a point to open the evaluation panel with its Competition and Cost-to-open tabs. The backend exposes `/nlquery`, `/site-eval`, `/competitor-analysis`, `/business-estimate` and `/health`. The original assistant dashboard (`/dashboard`, a chat assistant with a Leaflet heatmap that ranks areas) is kept as the baseline. The system runs on a standard laptop (Intel i5, 8 GB RAM, 20 to 50 GB of storage) using open-source software and open data throughout.

#figure(
  table(
    columns: (auto, 1fr),
    inset: 3pt,
    stroke: 0.5pt + gray,
    align: (left + horizon, left + horizon),
    fill: (x, y) => if x == 0 { silver } else { none },
    [*Presentation*], [React 19, MapLibre GL, Zustand; layer panel, query bar, evaluation panel],
    [*Application*], [FastAPI endpoints, LLM client (`groq_client.py`), MongoDB chat history],
    [*Tiles*], [Martin serving MVT from PostGIS],
    [*Data*], [PostgreSQL 16 + PostGIS 3.4 + pgvector; schemas `admin`, `roads`, `transport`, `poi`, `realestate`, `demo`, `crime`, `env`; `meta.schema_catalog`; `core.city`],
    [*ETL*], [OSMnx ingest, Nominatim geocoding, crime data migration],
  ),
  caption: [System component stack.],
) <fig-stack>

== Limitations

+ *Small benchmark.* The NL to SQL benchmark has 39 questions and was run once, so its accuracy figures carry substantial uncertainty, and it covers only filter, proximity, area, ranking, listing and compositional questions.
+ *Repair stage not exercised.* The engine retries after a database error or an empty result, but no query on the benchmark needed a retry, so the benefit of repair is unmeasured.
+ *Basic SQL safeguards.* Generated SQL runs under a read-only role with a statement timeout and a row cap, and is checked to be a single `SELECT`. The check is keyword-based and not a full SQL parser, and there is no table allow-list beyond the role's grants.
+ *No real rental data.* Rent is estimated from sale prices, so cost-to-open figures are approximate.
+ *Heuristic decision models.* The saturation bands, demand weights and per-type revenue benchmarks are set by judgement and have not been calibrated against real outcomes.
+ *LLM-generated cost items.* The non-rent setup and running costs, and the summary paragraph of the cost report, are written by the LLM and are not reconciled with the computed totals. Totals, profit and payback can therefore differ between runs for the same site, and the summary text can disagree with the figures beside it.
+ *Coarse listing locations.* Real-estate listings are geocoded at the locality level (228 localities), not per property.
+ *Radius-based catchments.* Catchments are circles, not travel-time isochrones.
+ *Data coverage.* Only Mumbai is loaded, and OSM completeness varies. Crime data is area-level.
+ *Model variability.* The LLM is called without a fixed temperature, so the same question can yield different SQL.
+ *No saved sites or mobile layout.* Pinned locations are not persisted, and the interface is designed for desktop.

= Results And Discussion

== Implemented System

The system is implemented end to end. @tab-data lists the Mumbai data currently loaded.

#figure(
  table(
    columns: (1fr, auto),
    inset: 3pt,
    stroke: 0.5pt + gray,
    fill: (x, y) => if y == 0 { silver } else { none },
    [*Dataset*], [*Size*],
    [Administrative boundaries], [48],
    [Road segments], [16.8k],
    [Transit stops], [2.2k],
    [Businesses and POIs], [10.8k],
    [Real-estate listings (CSV)], [76,000 rows],
    [Geocoded real-estate localities], [228],
    [Schema catalog entries], [34],
  ),
  caption: [Mumbai data loaded in the current instance.],
) <tab-data>

Compared with the POC, the GeoQuery workspace replaces invented coordinates with coordinates from the database, replaces random marker jitter with real geometries, replaces raster Leaflet maps with vector tiles, and replaces fixed synthetic metrics with metrics computed from nearby listings, transit and amenities.

== Qualitative Demonstration

A query such as "hospitals within 1 km of a metro station" is turned into a spatial SQL query, executed, and drawn as an answer layer, with the explanation and the SQL available in the panel. 
// #todo[add a screenshot of an NL query result with its SQL panel]

Clicking a location opens a site report with price, access, amenity and safety information, and the Competition and Cost-to-open tabs extend it to a business decision. @fig-decision shows this for a cafe at Vikhroli (B), compared with Kanjurmarg (A). The competition tab finds four cafes within 1.5 km, the nearest 1.3 km away, so both sites have no competitor within 1 km. It also suggests two lower-competition spots (green). The comparison table puts measured site attributes (price, transit, amenities, safety) next to the modelled business figures.

#figure(
  placement: top,
  scope: "parent",
  grid(
    columns: (1.47fr, 1fr),
    column-gutter: 6pt,
    row-gutter: 4pt,
    align: (center + horizon),
    image("fig_competition.jpg", width: 100%),
    image("fig_compare.jpg", width: 100%),
    text(size: 8pt)[(a) Competition tab for a cafe at Vikhroli (B), 1.5 km radius: competitors in red, suggested spots in green.],
    text(size: 8pt)[(b) Comparison of Kanjurmarg (A) and Vikhroli (B), cafe, standard tier.],
  ),
  caption: [Decision tools in the GeoQuery workspace. Site rows in (b) are measured within 1.5 km; rent, start-up cost, revenue, profit and payback are modelled estimates from a single run.],
) <fig-decision>

== Comparative Analysis

We compare the system along two axes: the query engine against its own ablations and against the direct-LLM approach of the POC, and the weighting schemes of the legacy area ranking.

=== Query engine versus ablations and the direct-LLM baseline

The benchmark in `eval/nl2sql/` contains 39 spatial questions in six categories (filters, proximity, named areas, rankings, listings and compositional queries), each with a hand-written gold SQL query. The expected answer is the executed result of the gold query, and a predicted layer is scored by comparing geometry sets (exact match and F1), so column names do not matter. Three configurations are compared: the full engine; the same engine restricted to its first generation attempt, obtained by re-executing the first SQL of each full run, which makes it a paired comparison; and the direct-LLM baseline, in which the model names places and coordinates without a database. The baseline returns no SQL, so it is scored on grounding: the share of returned names that exist in the database and the share of returned points that lie near a real feature. Results are from a single run with `openai/gpt-oss-120b` and default sampling. The intent-check and explanation calls were skipped, because they do not change the SQL.

#figure(
  table(
    columns: (1fr, auto, auto, auto),
    inset: 3pt,
    stroke: 0.5pt + gray,
    fill: (x, y) => if y == 0 { silver } else { none },
    [*Configuration*], [*Exact*], [*Geom. F1*], [*Executed*],
    [Full engine], [74.4%], [88.4%], [100%],
    [First attempt only (no repair)], [74.4%], [88.4%], [100%],
  ),
  caption: [Benchmark results on 39 questions, single run.],
) <tab-bench>

The full engine returns exactly the gold layer for 29 of the 39 questions (74.4%, geometry F1 88.4%), and every generated query executed and returned rows (@tab-bench, @fig-bench-category). The repair stage was never triggered: all 39 first attempts executed and returned rows, so the first-attempt-only configuration scores identically, and this benchmark shows no benefit from repair. Accuracy is highest for named-area and ranking questions (both 100%) and lowest for listings (25%). Eight of the ten failures come from a row cap and not from a wrong query. The engine's schema notes tell the model to use `LIMIT 500`, so questions whose gold answer is larger than 500 rows (hospitals, listings, hospitals near two kinds of station) are truncated, and joined queries without `DISTINCT` let duplicate rows use up the limit (for example the banks near bus stops and the schools in Bandra near bus stops). The other two failures are over-inclusive category choices: universities were matched together with colleges, and motorways with a pattern broader than the gold road class. We count all ten as failures, but they point to the prompt rules and to the exact-match scoring more than to a lack of spatial reasoning.

#figure(
  fig-category(),
  caption: [Exact-match accuracy by question category. The first-attempt-only configuration is identical to the full engine because no repair was needed.],
) <fig-bench-category>

The direct-LLM baseline gives a very different picture (@fig-bench-baseline). Only 19.5% of the place names it returned exist in the database, 57.0% of its coordinates lie within 150 m of some real feature, and only 10.6% lie within 200 m of a feature in the gold answer. The coordinate figure is generous, because Mumbai is dense and a random point is often near some point of interest, so the other two figures are more informative. The baseline also returns no SQL, so none of its answers can be checked. The median latency of the engine was 4.5 s, with a 95th percentile of 13.8 s (one LLM call plus the database, without the intent-check and explanation stages that the shipped engine adds) and that of the baseline 13.2 s. With 39 questions and one run, differences of a few questions should not be over-interpreted. A further ablation, in which the schema description lists only table names, is implemented in the benchmark code but was not run.

#figure(
  fig-baseline(),
  caption: [Grounding of the direct-LLM baseline (three left bars) next to the engine's geometry F1 against the gold answer (right bar). The metrics differ: the baseline bars show how much of its output is real, the engine bar its agreement with the gold layer.],
) <fig-bench-baseline>

=== Weighting schemes of the legacy ranking

The comparison of weighting schemes is described with the decision support models above. @fig-weight-tau shows how far each scheme's ranking is from the hand-picked one, and @fig-weight-oat shows how little the ranking changes when a single weight is changed by up to 30%.

#figure(
  fig-tau(),
  caption: [Rank agreement (Kendall's $tau$) of each weighting scheme with the hand-picked weights, and the overlap of the top-five areas.],
) <fig-weight-tau>

#figure(
  fig-oat(),
  caption: [One-at-a-time sensitivity: Kendall's $tau$ against the hand-picked ranking when one criterion's weight is changed by up to 30%, the others being renormalised.],
) <fig-weight-oat>

== Discussion

Grounding the model in a documented schema and returning the executed SQL changes the nature of the interface: answers can be checked, reproduced and corrected. The decision tools show that the same data supports practical questions, such as comparing three candidate shop locations on price, access, safety and competition.

The main weakness of the current work is evaluation. The benchmark is small, was run once, and did not exercise the repair stage, so we cannot say how much repair helps or how the engine behaves on harder questions. The safeguards, a read-only role, a statement timeout, a row cap and a single-statement check, limit the damage a malformed query can do, but they have not been tested against adversarial input. Cost and revenue estimates inherit the approximations in the rent model, the per-type benchmarks and the LLM-produced line items, and should be treated as planning aids. Because those line items are regenerated on each run, the same site can receive different start-up and payback figures, so the measured site attributes are more reliable than the modelled business figures. The weight study shows that the legacy area ranking is sensitive to the choice of weighting scheme.

= Conclusion And Future Scope

== Conclusion

GeoQuery shows that a natural-language interface to geospatial data can be built so that answers are computed on real data and are inspectable. By pairing a schema-grounded LLM with PostGIS, vector tiles and open data, it avoids the invented places and coordinates of direct LLM answers, and it extends the query engine with site evaluation, competition analysis, cost-to-open modelling and location comparison for practical decisions. The system is functional for Mumbai, and its ETL is designed to generalise. A first benchmark of 39 questions shows 74.4% exact-match accuracy against hand-written gold queries, with most failures caused by a row cap, whereas a direct-LLM baseline returns real place names only 19.5% of the time. A larger benchmark remains to be built.

== Future Scope
+ *Query reliability:* extend the benchmark (more questions, repeated runs, other models and harder queries that exercise the repair stage) in the style of Spider and BIRD @spider @bird @spatialt2s, and remove the row-cap and over-inclusion failures found here.
+ *Safety:* replace the keyword check with parser-based validation and a table allow-list.
+ *Data:* integrate real rental data, and extend the metrics modelling with LLM and OSM features where ground truth is scarce @geollm.
+ *Analysis:* replace radius catchments with isochrones, and calibrate the saturation bands and revenue benchmarks against real outcomes.
+ *Cost model:* fix the LLM line items per business type and tier (or cache them per site), and generate the report summary from the computed totals, so that repeated runs agree.
+ *Usability:* saved sites and a mobile layout.
+ *Coverage:* load additional cities using the existing ETL.




/*
@fig-plan reproduces the business plan generated by the Cost-to-open tab for a cafe at Vikhroli (19.1109, 72.9212), 800 sqft, standard tier. Rent, the security deposit and working capital follow the formulas in the decision support section. The other line items and the summary paragraph under the headline figures are written by the LLM. In this run the summary quotes an upfront cost and monthly expense that do not match the itemised totals below it, an example of the limitation noted earlier. The plan comes from a different run from the comparison in @fig-decision, so its start-up cost, profit and payback differ from the Vikhroli column there.

#figure(
  placement: top,
  scope: "parent",
  grid(
    columns: (1fr, 1fr),
    column-gutter: 8pt,
    align: top,
    image("fig_plan_1.jpg", width: 100%),
    image("fig_plan_2.jpg", width: 100%),
  ),
  caption: [Cost-to-open and break-even report for a cafe at Vikhroli. Left: one-time and monthly costs. Right: capital needed to start, modelled revenue scenarios and the assumptions used.],
) <fig-plan>
*/

#bibliography("refs.bib", full: false)
