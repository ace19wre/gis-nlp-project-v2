= Literature Survey

This chapter reviews the work that this project builds on. It looks at geospatial tools and web mapping, at natural-language interfaces to databases, at the recent use of LLMs for geospatial tasks, at spatial decision support, and at the open data and software that make the system possible. It ends with a summary of what each source contributes and the gap that this work addresses.

== Geospatial Analysis Tools and Web Mapping

Traditional GIS platforms such as ArcGIS and QGIS provide buffering, proximity analysis and spatial querying, but they assume knowledge of spatial concepts, data formats and query languages. Cloud platforms such as Felt and Mapbox improve collaboration and visualization @felt, yet users still drive them through layers, filters and map controls. Felt has also added AI features to its platform @felt. The layered, shareable web map is therefore a useful interaction model, and our workspace follows it: the user sees toggleable layers with legends on a vector-tile map.

== Natural-Language Interfaces to Databases

A natural-language interface to a database maps a question to an executable query. Spider @spider is a large human-labelled dataset for complex, cross-domain semantic parsing and text-to-SQL, designed so that systems are tested on databases they have not seen. BIRD @bird is a larger benchmark, with 12,751 question and SQL pairs over 95 databases of realistic size (33.4 GB in total) from 37 professional domains. Together these benchmarks have driven progress on general text-to-SQL, and LLM-based systems now dominate the leaderboards.

Spatial questions add difficulty. The model has to pick the right geometry types, apply spatial predicates and distance functions correctly, and respect coordinate reference systems. Early geospatial interfaces used rule-based mapping from keywords such as "near" and "within" to spatial operations. These work for simple queries but are brittle for ambiguous or compositional ones.

== Large Language Models for Geospatial Tasks

*Spatial text-to-SQL with multiple agents.* Kazazi et al. @spatialt2s present a multi-agent framework for spatial text-to-SQL. A notable component is an execution-based review stage, in which the generated query is run and the outcome is used to correct it. They report that the stage raises accuracy on their SpatialQueryQA benchmark from 76.7% to 87.7%, an improvement of about 11 points. That figure is a result from their work, not from ours. We follow the same design idea in a simplified form: our engine runs each generated query and uses a database error or an empty result to ask the model for a corrected query.

*Geospatial analysis for non-experts.* ChatGeoAI @chatgeoai converts natural-language requests into executable geospatial operations. It is built on a Llama 2 model and produces PyQGIS scripts for QGIS, so that users without programming skills can run analyses. Our system has the same goal of serving non-experts, but it targets a spatial database and returns a map layer together with the query that produced it.

*Geospatial knowledge in LLMs.* GeoLLM @geollm shows that LLMs hold geospatial knowledge and that combining the model with information from OpenStreetMap can model quantities for which ground truth is scarce. We treat this as relevant to estimating metrics, such as rent, where no direct data exists. In our system such modelled values are always labelled as estimates.

== Spatial Decision Support and Multi-Criteria Analysis

Spatial decision support systems extend GIS with multi-criteria decision analysis (MCDA) for tasks such as site selection @malczewski. They rank candidate locations by combining normalised criteria with weights, but typically need expert configuration and expert interpretation of the result. Our legacy dashboard used a weighted-sum model of this kind. Chapter 5 studies how sensitive that ranking is to the choice of weights, and the decision tools of the new system report measured quantities instead of a single weighted score.

== Open Geospatial Data and Tools

OpenStreetMap (OSM) provides free, globally available data on roads, amenities and land use @osm. It is produced by a community of volunteers in the same peer-production manner as Wikipedia, and its completeness varies from place to place. OSMnx @osmnx is a Python library that makes it easy to download and analyse OSM data, including extracts bounded by a city polygon. We use it to load any city into our database.

PostGIS adds spatial types, GiST indexing and spatial functions to the PostgreSQL database, which makes it a suitable target for generated queries: a single SQL statement can express a buffer, a distance filter and a join between layers. Martin serves Mapbox Vector Tiles directly from PostGIS, so the map is rendered from the same data that the queries use.

== Summary and Research Gap

#figure(
  table(
    columns: (2.3cm, 1fr, 1fr),
    align: (left + horizon, left + horizon, left + horizon),
    stroke: 0.5pt,
    inset: 5pt,
    table.header([*Source*], [*What it contributes*], [*How this project uses it*]),
    [Spider @spider\ BIRD @bird], [Benchmarks for general text-to-SQL], [Design reference for our benchmark of spatial questions],
    [Kazazi et al. @spatialt2s], [Multi-agent spatial text-to-SQL with an execution-based review stage], [Intent check, schema grounding, SQL generation and a bounded repair loop],
    [ChatGeoAI @chatgeoai], [Natural language to executable geospatial operations for non-experts], [Same goal; we generate SQL and show it with the map layer],
    [GeoLLM @geollm], [LLM knowledge combined with OSM features], [Relevant to modelled values such as rent, which we label as estimates],
    [Malczewski @malczewski], [Multi-criteria decision analysis with GIS], [Weighted-sum ranking in the legacy dashboard and its sensitivity study],
    [OSM @osm\ OSMnx @osmnx], [Open map data and tools to acquire it], [Source of roads, transit and businesses; polygon-based city ingest],
    [Felt @felt], [Layered, shareable web mapping with AI features], [Interaction model for the layered workspace],
  ),
  caption: [Related work and how each source is used in this project],
) <related>

Existing systems tend to cover either visualization, query processing or decision support. A system that lets the model answer directly is easy to build, but its output cannot be checked. The gap this project addresses is the combination of the three on one open-data stack, with the emphasis on verifiable query results: a natural-language question is translated into a validated spatial query, executed on real data, shown on a map with the SQL that produced it, and followed by decision tools that use the same data (@tbl:related).
