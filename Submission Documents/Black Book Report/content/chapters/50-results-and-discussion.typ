#import "/content/lilaq/figs.typ": fig-category, fig-baseline, fig-tau, fig-oat

= Results and Discussion

This chapter presents what the system does and how well it does it. It starts with the implemented system and the data it holds, shows the decision tools on a worked example, and then reports two studies: a benchmark of the query engine against hand-written gold queries, and a sensitivity study of the legacy weighted ranking. It ends with a discussion of what the results do and do not show.

== Implemented System

The system is implemented end to end: the database and tile server, the query engine, the decision tools and the web workspace. @tbl:data lists the Mumbai data that the current instance holds.

#figure(
  table(
    columns: (1fr, auto),
    inset: 5pt,
    align: (left + horizon, right + horizon),
    stroke: 0.5pt,
    table.header([*Dataset*], [*Size*]),
    [Administrative boundaries], [48],
    [Road segments], [16.8 thousand],
    [Transit stops], [2.2 thousand],
    [Businesses and points of interest], [10.8 thousand],
    [Real-estate listings (CSV rows)], [76,000],
    [Geocoded real-estate regions], [228],
    [Neighbourhoods with a safety score], [40],
    [Schema catalog entries], [34],
  ),
  caption: [Mumbai data loaded in the current instance],
) <data>

Compared with the proof of concept, the new workspace replaces invented coordinates with coordinates from the database, replaces random marker jitter with real geometries, replaces raster Leaflet maps with vector tiles, and replaces fixed synthetic metrics with metrics computed from nearby listings, transit and amenities. One exception should be noted: the real-estate listings have no coordinates of their own, so each is placed near the centre of its region (Chapter 3), and values computed from listings are therefore valid at the scale of a neighbourhood, not of a building.

== Qualitative Demonstration

A question such as "hospitals within 1 km of a metro station" is turned into a spatial SQL query, executed on the database and drawn as an answer layer, with the explanation and the SQL available in the side panel. Clicking a location opens a site report with price, access, amenity and safety information, and the Competition and Cost-to-open tabs extend it to a business decision.

@fig:competition-tab shows this for a cafe at Vikhroli. The competition tab finds four cafes within 1.5 km, the nearest 1.3 km away, so the spot has no competitor within 1 km and a low saturation label. The catchment demand index is 78 out of 100. The tab also suggests two lower-competition spots (green markers), one 1.4 km away with demand 54 and one 675 m away with demand 35, each with no competitor within 500 m. The comparison panel (@fig:compare-tab) puts the Vikhroli spot (B) next to Kanjurmarg (A). The measured rows differ in ways a decision maker can use: the nearest metro or rail stop is 719 m from B and 929 m from A, B has 172 amenities within 1.5 km against 46 for A, and A has the higher safety score (82 against 74). Both sites have the same median price per square foot (about 19,000 rupees) and neither has a competitor within 1 km.

#figure(
  image("/content/images/fig_competition.jpg", width: 100%),
  caption: [Competition tab for a cafe at Vikhroli (B), 1.5 km radius: competitors in red, suggested spots in green, with the catchment demand index and the nearest competitors in the side panel.],
) <competition-tab>

#figure(
  image("/content/images/fig_compare.jpg", width: 85%),
  caption: [Comparison of Kanjurmarg (A) and Vikhroli (B) for a standard-tier cafe. The site rows are measured within 1.5 km. Rent, start-up cost, revenue, profit and payback are modelled estimates from a single run.],
) <compare-tab>

The cost-to-open tab produces a full business plan (@fig:business-plan and @fig:business-plan-2). For an 800 square foot standard-tier cafe at Vikhroli it lists the one-time costs, the monthly costs, the capital needed to start, three revenue scenarios and the assumptions used. In this run the one-time setup comes to about 51.2 lakh rupees, the monthly running cost to about 4.8 lakh, and the base scenario gives a payback of 12.8 months. The rent line is derived from the sale prices of 3,410 nearby listings, and the report states that it is a derived value and not a listed rent.

#figure(
  image("/content/images/fig_plan_1.jpg", width: 82%),
  caption: [Cost-to-open report for a cafe at Vikhroli: headline figures, one-time costs and the start of the monthly costs.],
) <business-plan>

#figure(
  image("/content/images/fig_plan_2.jpg", width: 82%),
  caption: [Cost-to-open report, continued: capital needed to start, modelled revenue scenarios and the assumptions used.],
) <business-plan-2>

The plan also shows a limitation that Chapter 6 lists. The summary paragraph under the headline figures is written by the LLM, and in this run it quotes an upfront capital and a monthly expense that do not match the itemised totals below it. The itemised lines are the ones that are summed by the program; the text is not reconciled with them. The plan comes from a different run from the comparison in @fig:compare-tab, so its start-up cost, profit and payback differ from the Vikhroli column there. The size of that difference, with a similar rent in both runs, is consistent with the run-to-run variability of the LLM-produced line items, and it is the reason the report treats the measured site attributes as more reliable than the modelled business figures.

== Benchmark of the Query Engine

=== Method

The benchmark contains 39 spatial questions in six categories: filters (10), proximity (9), named areas (7), rankings (3), listings (4) and compositional queries (6). Each question has a hand-written gold SQL query. The expected answer is the executed result of the gold query, and a predicted layer is scored by comparing geometry sets with it (exact match and F1), so column names do not matter.

Three configurations are compared. The *full engine* is the system as shipped. The *first attempt only* configuration is the same engine restricted to its first generation attempt; it is obtained by re-executing the first SQL of each full run, which makes it a paired comparison. The *direct-LLM baseline* models the proof of concept: the model names places and coordinates without a database. The baseline returns no SQL, so it is scored on grounding instead: the share of returned names that exist in the database and the share of returned points that lie near a real feature.

The results are from a single run on 7 October 2026 with `openai/gpt-oss-120b` and default sampling. The intent-check and explanation calls were skipped in the benchmark, because they do not change the SQL.

=== Accuracy of the engine

The full engine returns exactly the gold layer for 29 of the 39 questions (74.4%, geometry F1 88.4%), and every generated query executed and returned rows (@tbl:bench-results). The repair stage was never triggered: all 39 first attempts executed and returned rows, so the first-attempt-only configuration scores identically, and this benchmark shows no benefit from repair.

#figure(
  table(
    columns: (1fr, auto, auto, auto),
    inset: 5pt,
    align: (left + horizon, center + horizon, center + horizon, center + horizon),
    stroke: 0.5pt,
    table.header([*Configuration*], [*Exact match*], [*Geometry F1*], [*Executed*]),
    [Full engine], [74.4%], [88.4%], [100%],
    [First attempt only (no repair)], [74.4%], [88.4%], [100%],
  ),
  caption: [Benchmark results on 39 questions, single run],
) <bench-results>

Accuracy by category is shown in @fig:bench-category. It is highest for named-area and ranking questions (both 100%) and lowest for listings (25%, one question of four). Ten questions failed. Eight of them come from a row cap and not from a wrong query: the schema notes tell the model to use `LIMIT 500`, so questions whose gold answer is larger than 500 rows are truncated, and joined queries without `DISTINCT` let duplicate rows use up the limit. The other two are over-inclusive category choices: universities were matched together with colleges, and motorways with a pattern broader than the gold road class. We count all ten as failures, but they point to the prompt rules and to the exact-match scoring more than to a lack of spatial reasoning.

#figure(
  fig-category(),
  caption: [Exact-match accuracy by question category. The first-attempt-only configuration is identical to the full engine because no repair was needed.],
) <bench-category>

=== The direct-LLM baseline

The direct-LLM baseline gives a very different picture (@fig:bench-baseline). Only 19.5% of the place names it returned exist in the database, 57.0% of its coordinates lie within 150 m of some real feature, and only 10.6% lie within 200 m of a feature in the gold answer. The coordinate figure is generous, because Mumbai is dense and a random point is often near some point of interest, so the other two figures are more informative. The baseline also returns no SQL, so none of its answers can be checked.

#figure(
  fig-baseline(),
  caption: [Grounding of the direct-LLM baseline (three left bars) next to the engine's geometry F1 against the gold answer (right bar). The metrics differ: the baseline bars show how much of its output is real, the engine bar its agreement with the gold layer.],
) <bench-baseline>

=== Latency

For the full configuration in the benchmark, which includes one LLM call and the database but not the intent-check and explanation stages that the shipped engine adds, the median latency was 4.5 s and the 95th percentile 13.8 s. The direct-LLM baseline took a median of 13.2 s and a 95th percentile of 27.1 s. With 39 questions and one run, differences of a few questions should not be over-interpreted. A further ablation, in which the schema description lists only table names, is implemented in the benchmark code but was not run.

== Sensitivity of the Weighted Ranking

The legacy dashboard ranked areas with the weighted sum of @eqt:mcda and hand-picked weights. To test how much its ranking depends on those weights, we ran a sensitivity study on the 40 scored areas. We compared the hand-picked weights with equal weights, rank-order centroid (ROC) weights, AHP weights (consistency ratio 0.011), entropy weights, CRITIC weights and three scenario weight sets (budget, student and premium), and we compared the weighted sum with TOPSIS under the baseline weights. Agreement with the baseline ranking was measured by Kendall's $tau$ and by the overlap of the top five areas. We also perturbed each weight by up to 30% one at a time, and drew 1,000 random weight vectors from a uniform Dirichlet distribution (seed 42) to see how often each area stays in the top five.

*Stable under small changes to one weight.* The worst-case $tau$ for a 30% change in any single weight is 0.90 or higher, lowest for the access weight (@fig:weight-oat).

*Not stable under a change of weighting scheme.* AHP, ROC and the premium scenario keep the same top five as the baseline ($tau$ of 0.92, 0.81 and 0.83). Equal weights, entropy weights, the student scenario, the budget scenario, TOPSIS and CRITIC share only 2, 2, 2, 1, 1 and 0 of the baseline's top five areas ($tau$ of 0.41, 0.58, 0.87, -0.11, 0.36 and -0.01), as shown in @fig:weight-tau. Across random weight vectors the median $tau$ against the baseline is 0.33 (5th to 95th percentile: -0.49 to 0.84), and no area stays in the top five in more than 45% of draws (Andheri West is highest at 44.5%).

#figure(
  fig-tau(),
  caption: [Rank agreement (Kendall's $tau$) of each weighting scheme with the hand-picked weights, and the overlap of the top-five areas.],
) <weight-tau>

#figure(
  fig-oat(),
  caption: [One-at-a-time sensitivity: Kendall's $tau$ against the hand-picked ranking when one criterion's weight is changed by up to 30%, the others being renormalised.],
) <weight-oat>

The weights therefore encode a preference, not a neutral measurement, which is one reason the new workspace uses measured spatial queries in place of this fixed ranking. These results describe the 40-area scored dataset and should not be read as evidence about real-world site quality.

== Evaluation Status

@tbl:status summarises what has and has not been measured.

#figure(
  table(
    columns: (1fr, 1fr),
    inset: 5pt,
    align: (left + horizon, left + horizon),
    stroke: 0.5pt,
    table.header([*Measurement*], [*Status*]),
    [NL-to-SQL execution accuracy on a labelled benchmark of spatial questions], [39 questions, single run: 74.4% exact match, 88.4% geometry F1],
    [Effect of the execution-based repair stage], [Repair never triggered on the benchmark (0 of 39 questions), so no measurable effect],
    [Latency of the query endpoint and the decision endpoints], [Query generation step: median 4.5 s, 95th percentile 13.8 s; decision endpoints not measured],
    [Weight sensitivity of the area ranking], [Done on the 40-area dataset],
    [Accuracy of the rent estimate against real rents], [Not possible: there is no rental data],
  ),
  caption: [What has and has not been measured],
) <status>

== Discussion

Grounding the model in a documented schema and returning the executed SQL changes the nature of the interface: answers can be checked, reproduced and corrected. The contrast with the baseline is large. When the model has to name places itself, fewer than one in five of the names it gives exist in the database, whereas the engine returns the gold layer for about three questions in four and its failures are explainable. The decision tools show that the same data supports practical questions, such as comparing three candidate shop locations on price, access, safety and competition.

The main weakness of the current work is evaluation. The benchmark is small, was run once, and did not exercise the repair stage, so we cannot say how much repair helps or how the engine behaves on harder questions. The safeguards (a read-only role, a statement timeout, a row cap and a single-statement check) limit the damage a malformed query can do, but they have not been tested against adversarial input.

Cost and revenue estimates inherit the approximations in the rent model, the per-type benchmarks and the LLM-produced line items, and should be treated as planning aids. Because those line items are regenerated on each run, the same site can receive different start-up and payback figures. The measured site attributes (counts, distances, median prices and safety scores) are therefore more reliable than the modelled business figures, and the interface and the report both label which is which.
