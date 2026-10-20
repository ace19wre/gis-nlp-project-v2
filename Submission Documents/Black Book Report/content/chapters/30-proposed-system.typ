#import "@preview/fletcher:0.5.8" as fletcher: node, edge

= Proposed System

This chapter describes the system that was built: its overall architecture, the requirements it meets, the pipeline that turns a question into a map layer, the database, the query engine and the decision models. Everything described here is implemented; Chapter 4 gives the implementation details and Chapter 5 the results.

== System Overview

The system has three layers (@fig:sys-overview). The *presentation layer* is a web application built with React and MapLibre GL. It shows a full-screen vector-tile map with a panel of toggleable layers, a natural-language query bar, and panels for evaluating, comparing and costing locations. The *application layer* is a FastAPI backend. It receives questions and location requests, calls the LLM through a single client module, queries the database and returns JSON and GeoJSON. The *data layer* is a PostgreSQL database with the PostGIS extension, which holds all spatial data, and the Martin tile server, which publishes the same tables as vector tiles.

#figure(
  fletcher.diagram(
    node-stroke: 0.8pt,
    node-shape: rect,
    node-inset: 7pt,
    node-corner-radius: 3pt,
    spacing: (22mm, 16mm),
    node((0, 0), align(center)[*Web application*\ #text(size: 9pt)[React, MapLibre GL,\ Zustand]], name: <ui>),
    node((1, 0), align(center)[*FastAPI backend*\ #text(size: 9pt)[NL query and\ decision endpoints]], name: <api>),
    node((2, 0), align(center)[*LLM (Groq API)*\ #text(size: 9pt)[intent, SQL,\ explanation]], name: <llm>),
    node((0, 1), align(center)[*Martin*\ #text(size: 9pt)[vector tiles]], name: <tiles>),
    node((1, 1), align(center)[*PostgreSQL + PostGIS*\ #text(size: 9pt)[spatial data,\ read-only role]], name: <db>),
    edge(<ui>, <api>, "<->", label: text(size: 8pt)[JSON, GeoJSON]),
    edge(<api>, <llm>, "<->", label: text(size: 8pt)[prompts]),
    edge(<api>, <db>, "->"),
    edge(<db>, <tiles>, "->"),
    edge(<tiles>, <ui>, "->", label: text(size: 8pt)[MVT tiles], label-side: left),
  ),
  caption: [Architecture of the system],
) <sys-overview>

A question travels through the system as follows. The browser sends it to the backend, where an LLM pipeline checks the intent of the question, grounds it in a description of the schema and generates a PostGIS query. The query is validated and executed on the database under a read-only role. If the database returns an error or no rows, a correction loop asks the model for a better query. The resulting rows are converted into a GeoJSON answer layer, which the map draws above the base layers together with an explanation and the SQL. The decision tools reuse the same database through their own endpoints.

== Requirements

*Functional requirements.* The system shall:

+ accept a spatial question in plain English and return an answer layer on the map, a short explanation and the SQL that was executed;
+ ask a short follow-up question when the target of a question cannot be determined;
+ display the base layers (boundaries, roads, transit stops, businesses, real-estate listings, safety score) with a legend and an opacity control for each;
+ produce a site report for a clicked location, a competition and catchment analysis for a business type, a cost-to-open and break-even estimate, and a side-by-side comparison of up to three locations;
+ load a new city from OpenStreetMap and the other sources without changes to the code.

*Non-functional requirements.* Answers must be verifiable (no place or number is invented by the model); generated SQL must never be able to modify data; the application must start and report errors cleanly when the database or the LLM is unavailable; and the whole stack must be reproducible on a standard computer with open-source software.

== Methodology of the Query Engine

The query engine is a pipeline of focused steps (@fig:qe-pipeline). Each LLM call has a narrow job and a fixed output format.

#figure(
  fletcher.diagram(
    node-stroke: 0.8pt,
    node-shape: rect,
    node-inset: 6pt,
    node-corner-radius: 3pt,
    spacing: (20mm, 20mm),
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
    edge(<exe>, <gen>, "-->", label: text(size: 8pt)[error or 0 rows], label-side: left),
  ),
  caption: [Pipeline of the natural-language query engine],
) <qe-pipeline>

+ *User input.* The user types a spatial question, either exploratory ("hospitals within 1 km of a metro station") or decision-oriented.
+ *Intent check.* A first LLM call decides whether the question is a clear spatial query and labels its task type (filter, proximity, ranking, aggregation, site selection or other). If the target is genuinely unknowable, for example "best place?", the system returns a short follow-up question instead of running a query.
+ *Schema grounding and SQL generation.* The second call receives a compact description of the queryable schema and writes one PostGIS query. Because the model can only reference tables and columns that exist, it cannot invent places.
+ *Validation and execution.* The query is checked and then executed on the database under a read-only role.
+ *Repair.* If the query fails or returns no rows, the error or a hint to loosen the query is sent back to the model, within fixed limits.
+ *Result generation.* The rows are converted into a GeoJSON answer layer, and a third call writes a short explanation based on the rows that were actually returned.

The design follows the multi-agent spatial text-to-SQL approach of Kazazi et al. @spatialt2s in a simplified form: it uses the intent, grounding, generation and execution-review stages, but keeps the stages in one service and uses a fixed schema description instead of retrieval.

== Database Design

All spatial data lives in one PostgreSQL 16 database with the PostGIS 3.4 extension. The data is divided into ten schemas, one per layer group (@tbl:schemas). All geometry is stored in EPSG:4326, and metric operations cast to the `geography` type at query time. Every feature table has a `city_id` column that refers to `core.city`, so one database can hold several cities and every query is scoped to one of them.

#figure(
  table(
    columns: (2.7cm, 3.6cm, 1fr),
    align: (left + horizon, left + horizon, left + horizon),
    stroke: 0.5pt,
    inset: 4pt,
    table.header([*Schema*], [*Table*], [*Main columns*]),
    [`core`], [`city`], [name, country, centroid, bounding box, status],
    [`admin`], [`boundary`], [name, admin level, kind (city, ward), multipolygon],
    [`roads`], [`segment`], [name, highway class, maximum speed, one-way flag, line],
    [`transport`], [`stop`, `line`], [name, mode (bus, metro, rail, tram), point or line],
    [`poi`], [`place`], [name, category, tags (JSON), point],
    [`realestate`], [`listing`], [locality, BHK, type, area in sqft, price, price unit, status, age, point],
    [`demo`], [`cell`], [population, density, median age, income index, polygon],
    [`crime`], [`area`, `incident_agg`], [name, zone, safety score (0 to 100), risk level, breakdown; aggregated incidents],
    [`env`], [`measurement`], [kind (air quality, flood risk), value, timestamp, geometry],
    [`meta`], [`schema_catalog`], [table and column names, data type, geometry flag, description, vector embedding],
  ),
  caption: [Schemas and tables of the spatial database],
) <schemas>

The geometry columns of the feature tables have GiST spatial indexes and their `city_id` columns have B-tree indexes; the category column of `poi.place` is indexed for category filters and the locality column of `realestate.listing` has a trigram index for fuzzy name matching. Two points in the design deserve mention:

- *Neighbourhood gazetteer.* OpenStreetMap ward names are administrative codes such as "K/W Ward" and do not contain neighbourhood names like "Bandra". The `crime.area` table has about 40 named neighbourhood points, so the engine uses it to resolve a colloquial area name to a location.
- *Schema catalog.* The `meta.schema_catalog` table documents every table and column (34 rows in the current instance) and has a vector column for embedding-based retrieval. The query engine does not read this table at query time; instead the same description is written into the prompt (next section).

Two database roles are used. The owner role is used by the ETL pipeline and by the decision endpoints. The `geo_readonly` role, which has `SELECT` rights on the data schemas and nothing else, is the only role that executes LLM-generated SQL.

== Query Engine Design

*Intent agent.* The first prompt describes the available data and asks for strict JSON with four fields: whether the question is clear, its task type, a one-sentence confirmation or follow-up question, and the entities it mentions. The prompt tells the model to lean towards "clear" and to ask for clarification only when the target is genuinely unknowable.

*SQL agent.* The second prompt contains a compact description of the schema and a set of rules. The description lists each table with its geometry type and the allowed values of its key categorical columns, for example the transit `mode` values and the `poi.place` categories. The rules are:

- filter every table by `city_id`;
- businesses and amenities live only in `poi.place`, and transit stops are never amenities;
- resolve neighbourhood names through the `crime.area` gazetteer with an `ILIKE` match and a distance buffer;
- return exactly one read-only `SELECT` statement that exposes a geometry column named `geom`;
- use `geography` casts for distances in metres, match names with `ILIKE`, and use `ORDER BY` with a `LIMIT` of at most 500 when ranking;
- never reference a table or column that is not listed.

*Validation.* The text returned by the model is cleaned of any markdown fence and then checked by a short function (@lst:validate). It must be a single statement that starts with `SELECT` or `WITH`, and it must not contain a data-modifying or definition keyword. The check is deliberately simple; the read-only role is the second, stronger barrier.

#figure(
  ```python
  _FORBIDDEN = re.compile(
      r"\b(insert|update|delete|drop|alter|create|truncate|grant|"
      r"revoke|copy|vacuum|call|merge|do)\b", re.IGNORECASE)

  def validate_select(sql: str) -> str:
      s = _strip_sql(sql).rstrip(";").strip()
      if ";" in s:
          raise ValueError("multiple statements are not allowed")
      low = s.lower()
      if not (low.startswith("select") or low.startswith("with")):
          raise ValueError("query must be a SELECT")
      if _FORBIDDEN.search(s):
          raise ValueError("query contains a forbidden keyword")
      return s
  ```,
  caption: [Validation of generated SQL before execution],
) <validate>

*Execution.* The validated query is wrapped so that the database itself builds a GeoJSON `FeatureCollection` with `ST_AsGeoJSON`, limited to 5,000 features. It runs as `geo_readonly` with a 15 second statement timeout.

*Repair.* If validation or execution fails, the first line of the error text (at most 400 characters) is sent back to the model with a request for a corrected query. At most two such repairs are made. If a valid query returns zero rows, the model is asked once to loosen the query, for example by using `ILIKE` instead of equality, resolving area names through the gazetteer, or widening the buffer. In total there are at most four attempts. The best successful attempt is kept, preferring one that returned rows, and every attempt is returned to the client so that the interface can show what was tried.

*Explanation agent.* The third prompt receives the question, the number of rows and the properties of up to 15 returned features, and writes two to four sentences describing what was found. If the explanation call fails, the engine returns a plain count instead.

== Decision Support Models

The decision tools are built on the same database and are exposed as separate endpoints. They separate what is *measured* (counts, distances and median prices computed from the data) from what is *modelled* (rent, revenue and payback), and the interface labels the second kind as estimates.

=== Site evaluation

For a clicked point and a radius, the report gives the median price per square foot of nearby listings with a typical price band, a comparison with the city median, a breakdown by size band, the nearest metro, rail and bus stops, amenity counts in five groups (healthcare, education, food, banking and shopping), a safety score with a risk level taken from the nearest `crime.area` point, and the best available locality name. Everything in this report is measured.

=== Competition and catchment analysis

Competitors are the points in `poi.place` whose category matches the business type inside the chosen radius $r$ (for a cafe, the category `cafe`). The report gives their count $n$, the nearest one and the density

$ rho = n / (pi r^2) $ <density>

in competitors per square kilometre. A saturation label follows fixed bands: below 5 is low, 5 to 15 moderate, 15 to 30 high and above 30 saturated.

The catchment demand index counts the points of interest in five groups and the transit stops inside the radius. Each count $c_k$ is capped at a saturation value $C_k$ (40 for healthcare, 25 for education, 40 for food, 15 for banking, 30 for shopping and 12 for transit stops), so that very dense areas do not dominate, and the capped counts are combined with business-specific weights $w_k$:

$ D = "round"(100 (sum_k w_k min(c_k / C_k, 1)) / (sum_k w_k)) $ <demand>

For a cafe the weights are 0.25 for education, 0.20 for shopping, 0.10 each for banking and food, 0.05 for healthcare and 0.30 for transit; other business types have their own weights, and a default set is used for unknown types.

To suggest gaps, a $5 times 5$ grid of candidate spots is laid over the radius. For each spot the same index $D$ is computed within 500 m, and the opportunity score is

$ O = D / (1 + n_(500)) $ <opportunity>

where $n_(500)$ is the number of competitors within 500 m of the spot. Up to three spots with $D >= 15$ and an opportunity score at least 15% higher than that of the evaluated spot are suggested. The saturation bands and the demand weights are heuristics set by judgement; they have not been calibrated against business outcomes.

=== Cost-to-open and break-even

The estimator takes the business type, a store area $A$ in square feet and a tier (economy, standard or premium). Because the dataset has no rental listings, the monthly rent is derived from sale prices:

$ R = p_"med" dot 0.005 dot 1.15 dot A $ <rent>

where $p_"med"$ is the median sale price per square foot of listings within 2.5 km, 0.005 is a monthly rent-to-value ratio and 1.15 is a commercial premium. If no listing is found nearby, a city default of 120 rupees per square foot per month is used. The security deposit is six months of rent, and the working capital is three months of the total monthly cost. The remaining line items (interior, furniture, equipment, initial stock, licences, branding, utilities, marketing and staff) are produced by the LLM from a prompt that fixes the rent; if the LLM is unavailable a heuristic fallback based on floor area is used, so the tool never fails.

The revenue model estimates the customers per day $N$ as

$ N = A / 100 dot beta dot f dot g $ <customers>

where $beta$ is a benchmark rate of customers per day per 100 square feet for the business type (@tbl:bench), $f$ is a footfall multiplier and $g$ a competition factor:

$ f = 0.6 + 0.8 min(1, a / 120) + 0.1 b, quad g = max(0.6, 1 / (1 + 0.04 n)) $ <factors>

Here $a$ is the number of amenities within 1 km, $b$ is 1 if a metro or rail stop lies within 800 m and 0 otherwise, and $n$ is the number of competitors of the same type within 1 km. The footfall multiplier therefore ranges from 0.6 in a quiet pocket to 1.5 in a dense, transit-served one. Monthly revenue for a scenario with customer multiplier $m$ (0.7 for conservative, 1.0 for base and 1.3 for optimistic) is

$ V = m N t dot 30 $ <revenue>

where $t$ is the average ticket, scaled by 0.8, 1.0 or 1.3 for the economy, standard and premium tiers. With cost of goods $c$ as a fixed share of revenue and fixed monthly costs $F$ (the monthly total without the restock line, which $c$ replaces), the profit, the payback in months and the break-even revenue are

$ P = V (1 - c) - F, quad T = U / P, quad V^* = F / (1 - c) $ <profit>

where $U$ is the one-time setup cost. The per-type benchmarks are modelling assumptions set by the authors and are not measured values (@tbl:bench).

#figure(
  table(
    columns: (3.4cm, 1fr, 1fr, 1fr),
    align: (left + horizon, center + horizon, center + horizon, center + horizon),
    stroke: 0.5pt,
    inset: 4pt,
    table.header([*Business type*], [*Customers per day per 100 sqft ($beta$)*], [*Average ticket $t$ (rupees)*], [*Cost of goods $c$*]),
    [Cafe], [18], [300], [30%],
    [Restaurant], [9], [650], [33%],
    [Pharmacy], [30], [450], [72%],
    [Clinic], [5], [700], [10%],
    [Grocery store], [22], [400], [78%],
    [Gym], [1.5], [1,800], [5%],
  ),
  caption: [Revenue benchmarks for six of the business types supported (modelled assumptions)],
) <bench>

=== Location comparison

Up to three pinned spots (A, B and C) are shown side by side across price, access, safety, number of competitors, rent, start-up cost, revenue, profit and payback. The best value in each row is marked. The site rows are measured within 1.5 km; the business rows are the modelled estimates described above.

=== Weighted ranking of areas (legacy dashboard)

The original dashboard ranks areas with a standard weighted-sum multi-criteria model @malczewski. For area $i$ with criteria $m_(i k)$ (footfall, youth, access, rent and competition, each scored from 0 to 10) the score is

$ S_i = sum_(k=1)^K w_k thin m'_(i k), quad sum_(k=1)^K w_k = 1 $ <mcda>

where $m'_(i k) = m_(i k)$ for benefit criteria (footfall, youth, access) and $m'_(i k) = 10 - m_(i k)$ for criteria where lower is better (rent and competition). The hand-picked weights are 0.30, 0.25, 0.20, 0.15 and 0.10 in that order. In the POC the metrics were synthetic, which is why the new decision tools do not use this ranking; Chapter 5 studies how sensitive it is to the choice of weights.

== Data Sources and ETL Design

The ETL pipeline loads one city at a time and each layer runs independently, so a failure in one layer does not stop the others. A city is marked ready when its core layers have loaded. The pipeline can be re-run for the same city: each layer first clears that city's rows and then inserts them again.

- *OpenStreetMap.* The city polygon is resolved first. Administrative boundaries, the road network (major road classes), transit stops and points of interest are then extracted inside that polygon with OSMnx @osmnx and stored with the city identifier.
- *Real estate.* A house-price dataset of about 76,000 rows is loaded. The data has no coordinates, so each distinct region (228 in the current instance) is geocoded once with Nominatim and the result is cached. Every listing is placed at the centre of its region plus a small deterministic offset of up to about 0.006 degrees (roughly 700 m), so that listings of the same region form a readable cloud instead of stacking on one point. Listing positions are therefore indicative of the region and are not property-level.
- *Crime and safety.* An area-level dataset gives each of about 40 Mumbai neighbourhoods a safety score from 0 to 100, a risk level and a breakdown by category. It is stored as points and doubles as the neighbourhood gazetteer.
- *Schema catalog.* A final step writes the schema description into `meta.schema_catalog`.

== User Interface Design

The main workspace is a full-screen vector-tile map. The layers are defined in one registry, so adding a layer is a single entry. The current layers, in their groups, are administrative boundaries; the road network and transit stops (coloured by mode); businesses and points of interest (coloured by category); real-estate listings; and the area-level safety score (red for lower, amber for medium and green for higher safety). Each layer can be switched on and off and has an opacity control and a legend.

The query bar sits on the map. A question returns an answer layer drawn above the base layers, with the explanation and the generated SQL in a side panel. A button lets the user click any point on the map to open the evaluation panel, which has the site report, a *Competition* tab and a *Cost-to-open* tab. Competitors are drawn as red dots and suggested spots as numbered green markers. Locations can be pinned and compared in a comparison panel. Clicking any feature on the map shows its attributes.

== Security and Safety Design

Generated SQL is treated as untrusted. Four barriers apply, in this order: the prompt forbids anything but one `SELECT`; the validation function rejects multiple statements and definition or modification keywords; the query runs as the `geo_readonly` role, which can only read; and the statement timeout (15 seconds) and the feature cap (5,000) limit the cost of a bad query. The backend's own queries pass their values as bound parameters. The two checks in front of the database are simple and are not a full SQL parser, which is listed as a limitation in Chapter 6.

The backend is written so that it starts when the database or the LLM is unavailable. Endpoints then report the failure instead of crashing, and each LLM-backed feature has a deterministic fallback, as the cost estimator does. Secrets such as the API key are read from environment files and are not stored in the repository.
