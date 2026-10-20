= Conclusion and Future Scope

== Conclusion

This project set out to build a system in which anyone can ask a spatial question in plain English and receive an answer that is computed on real data and can be checked. The system that was built does this. A question is checked for intent, translated by an LLM into a PostGIS query that is grounded in a documented schema, validated, executed under a read-only database role and, when needed, corrected. The result is shown as a layer on a vector-tile map together with a short explanation and the SQL that produced it.

On top of the query engine, four decision tools use the same database: a site report for any clicked location, a competition and catchment analysis with suggested alternative spots, a cost-to-open and break-even estimator, and a side-by-side comparison of up to three locations. They separate what is measured from what is modelled and label the second kind as an estimate. A loading pipeline driven by a city polygon fills the database from OpenStreetMap, a real-estate dataset and an area-level safety dataset, so the design is not tied to one city, although only Mumbai has been loaded.

A first benchmark of 39 spatial questions shows that the engine returns exactly the gold answer for 74.4% of them (geometry F1 88.4%), and every generated query ran. Most of its failures come from a row cap and the exact-match scoring rather than from a lack of spatial reasoning. A direct-LLM baseline that names places and coordinates without a database returned names that exist in the database only 19.5% of the time, and none of its answers could be checked. These results support the central idea of the work: that having the model write a query that is executed on real data is more reliable and more transparent than having it answer directly. A larger benchmark remains to be built.

== Limitations

+ *Small benchmark.* The NL-to-SQL benchmark has 39 questions and was run once, so its accuracy figures carry substantial uncertainty, and it covers only filter, proximity, area, ranking, listing and compositional questions.
+ *Repair stage not exercised.* The engine retries after a database error or an empty result, but no query on the benchmark needed a retry, so the benefit of repair is unmeasured.
+ *Basic SQL safeguards.* Generated SQL runs under a read-only role with a statement timeout and a row cap, and is checked to be a single `SELECT`. The check is keyword-based and not a full SQL parser, and there is no table allow-list beyond the role's grants.
+ *No real rental data.* Rent is estimated from sale prices, so cost-to-open figures are approximate.
+ *Heuristic decision models.* The saturation bands, demand weights and per-type revenue benchmarks are set by judgement and have not been calibrated against real outcomes.
+ *LLM-generated cost items.* The non-rent setup and running costs, and the summary paragraph of the cost report, are written by the LLM and are not reconciled with the computed totals. Totals, profit and payback can therefore differ between runs for the same site, and the summary text can disagree with the figures beside it.
+ *Coarse listing locations.* Real-estate listings are placed near the centre of their region (228 regions) with a small deterministic offset of up to about 700 m, not at their real address.
+ *Radius-based catchments.* Catchments are circles, not travel-time isochrones.
+ *Data coverage.* Only Mumbai is loaded, and OSM completeness varies. Crime data is area-level.
+ *Model variability.* The LLM is called without a fixed temperature, so the same question can yield different SQL.
+ *No saved sites or mobile layout.* Pinned locations are not persisted, and the interface is designed for desktop.

== Future Scope

+ *Query reliability:* extend the benchmark (more questions, repeated runs, other models and harder queries that exercise the repair stage) in the style of Spider and BIRD @spider @bird @spatialt2s, and remove the row-cap and over-inclusion failures found here.
+ *Safety:* replace the keyword check with parser-based validation and a table allow-list.
+ *Data:* integrate real rental data, and extend the metrics modelling with LLM and OSM features where ground truth is scarce @geollm.
+ *Analysis:* replace radius catchments with travel-time isochrones, and calibrate the saturation bands and revenue benchmarks against real outcomes.
+ *Cost model:* fix the LLM line items per business type and tier (or cache them per site), and generate the report summary from the computed totals, so that repeated runs agree.
+ *Usability:* saved sites and a mobile layout.
+ *Coverage:* load additional cities using the existing ETL.
