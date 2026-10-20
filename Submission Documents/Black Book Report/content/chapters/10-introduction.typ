= Introduction

== Background

Almost every decision about land and buildings starts with a question about a place. Where should a clinic be built so that people can reach it? Which neighbourhood is safe and well connected for a family? Where can a new cafe open without being drowned out by competitors? Answering questions like these needs spatial data (roads, transit stops, buildings, businesses, property prices) and a way to combine it.

Geographic Information Systems (GIS) are the traditional tools for this work. Desktop systems such as ArcGIS and QGIS offer buffering, proximity analysis and spatial queries, but they assume that the user understands spatial data formats, coordinate systems and query languages such as SQL. A business owner who has a location question but no GIS training is therefore left outside the process. Web mapping platforms such as Felt @felt have made it much easier to build, share and discuss maps, yet the user still has to turn a real-world question into manual operations on layers and filters.

Large language models (LLMs) offer another way in: the user simply types the question in plain English. Recent work shows that LLMs can write executable queries for structured data and can even drive geospatial software @chatgeoai @spatialt2s. The risk is how the model is used. If the model is asked to answer the question itself, it may invent place names and coordinates, and nothing in its answer can be checked against data.

== Motivation

Our first proof of concept (POC) took exactly this direct approach, and it exposed three weaknesses. The model invented area names and coordinates. Areas were ranked by a fixed, hand-weighted formula over about 40 areas whose 1 to 10 metrics were synthetic. Map markers were placed with random coordinate jitter on Leaflet raster maps, so no real spatial computation took place. The assistant answered with familiar area names, but none of its output could be verified.

This motivated the central idea of the project: replace "the LLM hallucinates the answer" with "the LLM writes a structured spatial query that is executed on real data". The answer then comes from the database, it is reproducible, and the SQL that produced it can be shown to the user as evidence.

A second motivation is practical. A person deciding where to open a cafe must weigh nearby property prices, transit access, safety, competition and start-up cost. No single easy tool combines these, so the work is spread over maps, property listings and reports and can take weeks of manual survey. We wanted one system in which a question can be asked in plain English, the evidence is shown on a map, and the follow-up decision tools (site report, competition analysis, cost estimate, side-by-side comparison) use the same data.

== Societal and Environmental Context

The project works with data that describes how people live in a city, so its context goes beyond commerce. This section links the data layers of the system to public health, safety, society, the environment and sustainable development.

- *Public health.* The database holds hospitals, clinics, doctors and pharmacies from OpenStreetMap. Questions such as "hospitals within 1 km of a metro station" show how access to healthcare relative to public transport can be examined. Such answers may help an individual find a clinic, and the same query pattern can support a planner's review of access.
- *Safety.* The system includes an area-level safety score and risk level for neighbourhoods. A location report places this score next to price, transit and amenities, so safety is considered as part of the decision rather than discovered afterwards. The score is area-level only and describes an area, not a street or a person.
- *Society and economy.* Small businesses often decide on a location with little data. A tool that makes demand, competition and cost visible in one place lowers the barrier for owners without analysts. The database, tile server and map libraries are open source and the base data is open; the only external service is the hosted LLM that is called through an API.
- *Environment and sustainable development.* The transit layer (metro, rail, bus) and the amenity counts let a user see how well a place is served on foot and by public transport. Choosing locations that are close to public transport and daily amenities can reduce the need for long trips, which is consistent with the aims of sustainable and inclusive cities (United Nations Sustainable Development Goal 11). The system does not measure environmental outcomes itself; it makes the relevant spatial facts easy to see.
- *Ethics and responsible use.* The system uses open and aggregated data and does not collect personal data. Its cost and revenue figures are modelled estimates and are labelled as such, and the report states that they are planning aids and not financial advice. Every answer carries its SQL, so a reader can check how a result was obtained.

== Problem Statement

Geospatial analysis is essential for business planning, but existing GIS tools demand knowledge of spatial data and query languages and mostly leave users to interpret patterns by hand. A person deciding where to open a cafe must weigh prices, transit, safety, competition and start-up cost, and no single easy tool combines these. LLM interfaces lower the barrier, but when the model supplies the answer directly, place names and coordinates can be invented and nothing can be verified. A system is needed that accepts natural language, computes answers on real spatial data, shows how each answer was obtained, and supports practical location decisions.

== Objectives

The primary objective is to build a natural-language geospatial query and decision-support system whose answers are computed from real data. The specific objectives are:

+ *To provide a natural-language interface* that lets users ask spatial questions in plain English without SQL or GIS knowledge.
+ *To translate questions into PostGIS queries* using an LLM grounded in a documented schema, and to return the result as a map layer, an explanation and the SQL.
+ *To build a spatial data foundation* on PostgreSQL and PostGIS from OpenStreetMap, real-estate listings and crime data, with an ETL pipeline that generalises to other cities.
+ *To serve and render layers efficiently* using vector tiles, with a toggleable layer panel and click-to-inspect interaction.
+ *To support location decisions* through a site evaluation report, competition and catchment analysis, a cost-to-open and break-even estimator, and a side-by-side comparison of candidate locations.
+ *To keep results explainable* by generating plain-English explanations and exposing the executed SQL.
+ *To remain cost-effective* by using open-source tools and open data.

== Scope of the Work

The deployed instance is loaded with data for Mumbai: administrative boundaries, roads, transit stops, businesses and points of interest from OpenStreetMap, a 76,000-row house-price dataset, and an area-level crime and safety dataset. Every table carries a city identifier and the loading pipeline is driven by a city polygon, so the design supports other cities, but only Mumbai has been loaded and tested.

The user interface is a desktop web application. Questions are asked in English. The query engine returns one read-only query per question; it does not modify data. The decision tools are intended as planning aids: the measured parts (counts, distances, median prices) come from the database, and the modelled parts (rent, revenue, payback) are labelled as estimates. Real-time data, travel-time catchments and saved user sessions are outside the current scope (Chapter 6 lists them as future work).

== Contributions

The main contributions of this work are:

+ A natural-language to PostGIS query engine that grounds the LLM in a documented schema and returns a GeoJSON layer, an explanation and the executed SQL.
+ A real-data foundation: an ETL pipeline that loads OpenStreetMap, real-estate listings and crime data into one spatial database, designed to work for any city.
+ Decision tools (site evaluation, competition analysis, cost-to-open, location comparison) built on the same data.
+ An honest account of what is and is not yet validated, with a first benchmark of query accuracy on 39 spatial questions and the evaluation plan for the missing pieces.

== Organisation of the Report

Chapter 2 reviews related work on GIS tools, natural-language interfaces to databases, LLMs for geospatial tasks and spatial decision support. Chapter 3 describes the proposed system: its architecture, database design, query engine and decision models. Chapter 4 gives the implementation details, including the hardware and software used. Chapter 5 presents the results: the implemented system, a qualitative demonstration, the query-accuracy benchmark and a sensitivity study of the legacy ranking. Chapter 6 concludes the report and lists limitations and future scope.
