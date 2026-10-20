= Implementation

This chapter lists the hardware and software that the project uses and describes how each part of the design in Chapter 3 was implemented: the database and tile server, the backend, the data loading pipeline, the web interface, and the way the system is run and checked.

== Hardware Requirements

The system runs on a standard personal computer or laptop.

- *Processor:* Intel i5 or equivalent (a higher-end processor is recommended).
- *Memory:* at least 8 GB of RAM (16 GB recommended for large datasets).
- *Storage:* at least 20 to 50 GB of free space for the OpenStreetMap data and the database.
- *Network:* an internet connection for the LLM API and for geocoding.

== Software Requirements

The stack is primarily open source (@tbl:software). The only external service is the hosted LLM.

#figure(
  table(
    columns: (auto, 4.2cm, 1fr),
    inset: 4pt,
    align: (center + horizon, left + horizon, left + horizon),
    stroke: 0.5pt,
    table.header([*Sr. No.*], [*Software or tool*], [*Use in the project*]),
    [1], [PostgreSQL 16 with PostGIS 3.4], [Spatial database with GiST indexing; the `pgvector` and `pg_trgm` extensions are also installed],
    [2], [Martin 0.14], [Serves Mapbox Vector Tiles directly from PostGIS],
    [3], [Python 3.12, FastAPI and Uvicorn], [REST backend for the query engine and the decision tools],
    [4], [SQLAlchemy 2, asyncpg, GeoAlchemy2, Pydantic 2], [Asynchronous database access and request validation],
    [5], [Groq API, model `openai/gpt-oss-120b`], [LLM for intent checking, SQL generation, explanations and cost line items],
    [6], [React 19 and Vite 8], [Web interface and its build tool],
    [7], [MapLibre GL 4], [Vector-tile map rendering in the main workspace],
    [8], [Zustand 5, axios, React Router 7], [Shared map state, HTTP calls and page routing],
    [9], [Leaflet], [Map in the legacy dashboard only],
    [10], [OSMnx and GeoPandas], [Polygon-based OpenStreetMap extraction and spatial data handling in the ETL],
    [11], [Nominatim], [Geocoding of the real-estate regions],
    [12], [MongoDB], [Chat history of the legacy dashboard only],
    [13], [Docker Compose], [Runs the database and the tile server],
  ),
  caption: [Software used in the project],
) <software>

== Implementation of the Data Layer

*Database container.* The database runs in Docker. The image is built from the official `postgis/postgis:16-3.4` image, which bundles PostGIS 3.4 on PostgreSQL 16, with the `pgvector` package added. On the first start with an empty volume the container runs four initialisation scripts in order: the extensions (`postgis`, `postgis_raster`, `vector`, `pg_trgm`), the schema with all tables and indexes, the roles (including the read-only role), and a seed record for Mumbai. The database is published on host port 5433 so that it does not clash with a native PostgreSQL installation.

*Vector tiles.* Martin runs in a second container and connects to the same database. It is configured to publish every table of the data schemas automatically under the name `schema.table`, which is also the identifier that the web interface uses for each layer. The tile server is available on host port 3001.

*ETL pipeline.* The loader is run from the command line for one city at a time:

```
python -m etl.run --city "Mumbai, India"
```

It resolves the city polygon and then loads the administrative boundaries, ward polygons, roads, transit stops and points of interest from OpenStreetMap, geocodes and loads the real-estate dataset, loads the crime and safety dataset, and finally writes the schema catalog. Each layer runs independently, so one failing layer does not abort the others, and individual layers can be skipped with an option. Because extraction is driven by the city polygon, the same command loads any other city.

== Implementation of the Backend

The backend is a FastAPI application. Its entry point registers one router per feature, and each router is a thin module that defines the request model and calls a service, so that the logic can be tested without the web layer. @tbl:endpoints lists the current endpoints.

#figure(
  table(
    columns: (3.4cm, 1fr, 3.6cm),
    inset: 4pt,
    align: (left + horizon, left + horizon, left + horizon),
    stroke: 0.5pt,
    table.header([*Endpoint*], [*Purpose and main inputs*], [*Service*]),
    [`POST /nlquery`], [Natural-language question and city; returns the GeoJSON answer layer, explanation, SQL and the list of attempts], [`geo_engine`],
    [`POST /site-eval`], [Point and radius; returns the site report], [`site_evaluator`],
    [`POST /competitor-analysis`], [Point, business type and radius; returns competitors, saturation, demand index and suggested spots], [`competitor_analysis`],
    [`POST /business-estimate`], [Business type, point, area and tier; returns the cost and break-even estimate], [`business_estimator`],
    [`GET /health`], [Reports whether the application can reach the database], [],
  ),
  caption: [Endpoints of the backend],
) <endpoints>

The original dashboard additionally uses the earlier endpoints for analysis, generation, explanation, chat queries, location insight and property lookup. They are kept as the baseline and are not used by the new workspace.

*Two database engines.* The module that creates database connections offers two engines. The owner engine is used by the decision endpoints. The read-only engine, which logs in as `geo_readonly` and sets a 15 second statement timeout, is the only one the query engine may use, and it is only reached after the generated SQL has passed validation. Both engines are created lazily, so importing the application never fails when the database is down.

*LLM client.* All calls to the LLM go through a single module, which also contains a helper that parses the JSON replies of the model safely. Keeping one client makes the model easy to swap and means that prompts and parsing are in one place. Every feature that depends on the LLM has a fallback: the intent and SQL stages report a clear error, the explanation falls back to a row count, and the cost estimator falls back to a size-based heuristic.

*Decision services.* The three services described in Chapter 3 run their queries with bound parameters and compute the models in Python. The site report queries the nearby listings, the transit stops, the amenities and the nearest safety record. The competition service fetches the points of interest and transit stops around the point once and then computes the competitor list, the demand index and the $5 times 5$ grid scan in memory. The cost estimator combines a median-price query, an LLM call and the revenue model; the revenue part is additive, so a failure there never prevents the cost estimate from being returned.

== Implementation of the Web Interface

The interface is a single-page React application built with Vite. The main page, the *Studio*, contains the map and its panels:

- *Map canvas and layers.* MapLibre GL draws the base map and the vector-tile layers from Martin. The layers are described in one registry file, in which each entry gives the source, the paint rules (for example, transit stops coloured by mode and points of interest coloured by category), the legend and whether the layer is visible at start. A layer panel reads the same registry to build the toggles and opacity sliders.
- *Query bar.* The bar sends the question to `/nlquery` and draws the returned GeoJSON as a new layer above the base layers. A side panel shows the explanation and the SQL, and shows a follow-up question when the engine asks for one.
- *Evaluation panel.* A button lets the user pick a point on the map. The panel then shows the site report, a *Competition* tab and a *Cost-to-open* tab, and the radius can be changed. Competitors are drawn as red dots and the suggested spots as numbered green markers.
- *Comparison panel.* Up to three evaluated locations can be pinned and compared side by side.

Shared map state is kept in one Zustand store instead of being passed through component properties, and every HTTP call is defined in one API module. The earlier pages of the proof of concept (home, dashboard, crime map and chat query) are kept in the application as the baseline.

== Running the System

The system is started in three steps: the database and tile server with `docker compose up -d`, the backend with Uvicorn on port 8000, and the frontend with the Vite development server on port 3000. A script for Windows starts all three together. Settings such as the database connection strings, the tile server address and the LLM API key are read from environment files, and a template file lists every setting. After the first start the ETL command above loads a city; the tile server is then restarted so that it picks up newly created tables. The `/health` endpoint shows whether the backend can reach the database.

== Verification

The project has no automated unit-test suite. Verification was done in the following ways:

- *Benchmark script.* The query-accuracy benchmark in the evaluation folder has a lint mode that checks the question set without a database or an LLM, and a gold-validation mode that executes every hand-written gold query on the database without an LLM. The full benchmark then compares the engine with its ablations and with the direct-LLM baseline (Chapter 5).
- *Health check and manual testing.* The backend has a `/health` endpoint that reports whether it can reach the database. The endpoints and the interface were exercised by hand against the loaded Mumbai data; the screenshots in Chapter 5 come from such runs.
- *Minimum checks for a change.* The project convention is that the Python modules are syntax-checked, that the frontend passes its build and lint commands, and that `/health` and a real request succeed before a change is accepted.
