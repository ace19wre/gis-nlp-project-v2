// Builds the two ICDMAI Word files from the content below.
//   node build.js          (needs:  npm install docx   in this folder, or NODE_PATH set)
// Output (one level up):
//   ICDMAI_paper_anonymous.docx        for double-blind review (no author details)
//   ICDMAI_paper_with_title_page.docx  same paper with the required title page (for camera-ready)
// Figures: ../figures/fig-N.svg (+ .png fallback); screenshots: ../images/*.jpg
const fs = require('fs');
const path = require('path');
const D = require('docx');
const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell, Footer, AlignmentType,
  LevelFormat, WidthType, BorderStyle, ShadingType, HeadingLevel, PageNumber, TabStopType,
  ExternalHyperlink, Math: MathBlock, MathRun, MathSum, MathSubScript, VerticalAlign,
} = D;

const ROOT = path.join(__dirname, '..');
const FONT = 'Times New Roman';
const PT = (n) => n * 2; // half-points
const TEXT_W = 9026; // DXA: A4 width 11906 - 2 x 1440
const MAX_PX = 590; // 15.6 cm at 96 dpi

// ---------------------------------------------------------------- references (alphabetical by first author)
const REFS = [
  { key: 'osmnx', text: 'Boeing, G.: OSMnx: New methods for acquiring, constructing, analyzing, and visualizing complex street networks. Computers, Environment and Urban Systems 65, 126–139 (2017). ', doi: '10.1016/j.compenvurbsys.2017.05.004' },
  { key: 'felt', text: 'Felt: Felt AI: AI-powered GIS and mapping platform. Felt Help Center (2025). ', url: 'https://help.felt.com/felt-ai' },
  { key: 'osm', text: 'Haklay, M., Weber, P.: OpenStreetMap: User-generated street maps. IEEE Pervasive Computing 7(4), 12–18 (2008). ', doi: '10.1109/MPRV.2008.80' },
  { key: 'spatialt2s', text: 'Kazazi, A.K., Li, Z., Lessani, M.N., Cervone, G.: From questions to queries: An AI-powered multi-agent framework for spatial text-to-SQL. arXiv preprint arXiv:2510.21045 (2025). ', doi: '10.48550/arXiv.2510.21045' },
  { key: 'bird', text: 'Li, J., Hui, B., Qu, G., et al.: Can LLM already serve as a database interface? A big bench for large-scale database grounded text-to-SQLs. In: Advances in Neural Information Processing Systems (NeurIPS) (2023). ', doi: '10.48550/arXiv.2305.03111' },
  { key: 'malczewski', text: 'Malczewski, J.: GIS and Multicriteria Decision Analysis. John Wiley & Sons, New York (1999)' },
  { key: 'chatgeoai', text: 'Mansourian, A., Oucheikh, R.: ChatGeoAI: Enabling geospatial analysis for public through natural language, with large language models. ISPRS International Journal of Geo-Information 13(10), 348 (2024). ', doi: '10.3390/ijgi13100348' },
  { key: 'geollm', text: 'Manvi, R., Khanna, S., Mai, G., Burke, M., Lobell, D., Ermon, S.: GeoLLM: Extracting geospatial knowledge from large language models. In: International Conference on Learning Representations (ICLR) (2024). ', doi: '10.48550/arXiv.2310.06213' },
  { key: 'spider', text: 'Yu, T., Zhang, R., Yang, K., et al.: Spider: A large-scale human-labeled dataset for complex and cross-domain semantic parsing and text-to-SQL task. In: Proceedings of the 2018 Conference on Empirical Methods in Natural Language Processing (EMNLP), pp. 3911–3921. Association for Computational Linguistics, Brussels (2018). ', doi: '10.18653/v1/D18-1425' },
];
const REFNUM = Object.fromEntries(REFS.map((r, i) => [r.key, i + 1]));

// ---------------------------------------------------------------- inline markup
// **bold**  __italic__  `code`  [@a,@b] citation  ^sup^  ~sub~
const TOKEN = /(\*\*.+?\*\*|__.+?__|`.+?`|\[@[^\]]+\]|\^[^^]+\^|~[^~]+~)/g;
function runs(text, base = {}) {
  const out = [];
  for (const part of text.split(TOKEN)) {
    if (!part) continue;
    if (part.startsWith('**')) out.push(new TextRun({ ...base, text: part.slice(2, -2), bold: true }));
    else if (part.startsWith('__')) out.push(new TextRun({ ...base, text: part.slice(2, -2), italics: true }));
    else if (part.startsWith('`')) out.push(new TextRun({ ...base, text: part.slice(1, -1), font: 'Courier New', size: PT(10.5) }));
    else if (part.startsWith('[@')) {
      const nums = part.slice(1, -1).split(',').map((k) => {
        const key = k.trim().replace('@', '');
        if (!(key in REFNUM)) throw new Error('unknown citation key: ' + key);
        return REFNUM[key];
      }).sort((a, b) => a - b);
      out.push(new TextRun({ ...base, text: '[' + nums.join(', ') + ']' }));
    } else if (part.startsWith('^')) out.push(new TextRun({ ...base, text: part.slice(1, -1), superScript: true }));
    else if (part.startsWith('~')) out.push(new TextRun({ ...base, text: part.slice(1, -1), subScript: true }));
    else out.push(new TextRun({ ...base, text: part }));
  }
  return out;
}

// ---------------------------------------------------------------- block helpers
const P = (text, o = {}) => new Paragraph({
  children: runs(text, o.run || {}),
  alignment: o.align || AlignmentType.JUSTIFIED,
  spacing: { line: 240, before: o.before || 0, after: o.after === undefined ? 120 : o.after },
  keepNext: o.keepNext, indent: o.indent,
});
const H1 = (text) => new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text })], keepNext: true, spacing: { before: 240, after: 120 } });
const H2 = (text) => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text })], keepNext: true, spacing: { before: 160, after: 80 } });
const H3 = (text) => new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text })], keepNext: true, spacing: { before: 120, after: 60 } });
const LIST = (ref, items) => items.map((t) => new Paragraph({
  numbering: { reference: ref, level: 0 }, children: runs(t), alignment: AlignmentType.JUSTIFIED, spacing: { line: 240, after: 60 },
}));

function jpgSize(file) {
  const b = fs.readFileSync(file);
  let i = 2;
  while (i < b.length) {
    if (b[i] !== 0xff) { i++; continue; }
    const m = b[i + 1];
    if (m >= 0xc0 && m <= 0xc3) return { h: b.readUInt16BE(i + 5), w: b.readUInt16BE(i + 7) };
    i += 2 + b.readUInt16BE(i + 2);
  }
  throw new Error('no size in ' + file);
}
function svgSize(file) {
  const head = fs.readFileSync(file, 'utf8').slice(0, 400);
  const m = head.match(/width="([\d.]+)pt" height="([\d.]+)pt"/);
  return { w: (parseFloat(m[1]) * 96) / 72, h: (parseFloat(m[2]) * 96) / 72 };
}
function fit(w, h, maxW) { const k = Math.min(1, maxW / w); return { width: Math.round(w * k), height: Math.round(h * k) }; }

function svgImage(n, alt, maxW = MAX_PX) {
  const svg = path.join(ROOT, 'figures', `fig-${n}.svg`);
  const png = path.join(ROOT, 'figures', `fig-${n}.png`);
  const s = svgSize(svg);
  return new ImageRun({
    type: 'svg', data: fs.readFileSync(svg), fallback: { type: 'png', data: fs.readFileSync(png) },
    transformation: fit(s.w, s.h, maxW), altText: { title: `Figure ${n}`, description: alt, name: `fig-${n}` },
  });
}
function jpgImage(file, alt, maxW) {
  const f = path.join(ROOT, 'images', file);
  const s = jpgSize(f);
  return new ImageRun({ type: 'jpg', data: fs.readFileSync(f), transformation: fit(s.w, s.h, maxW), altText: { title: file, description: alt, name: file } });
}
const center = (children, keepNext = true) => new Paragraph({ children, alignment: AlignmentType.CENTER, keepNext, spacing: { line: 240, before: 120, after: 60 } });
const caption = (label, text) => new Paragraph({
  children: [new TextRun({ text: label + ' ', bold: true, size: PT(11) }), ...runs(text, { size: PT(11) })],
  alignment: AlignmentType.JUSTIFIED, spacing: { line: 240, after: 200 },
});
const subcap = (text) => new Paragraph({ children: runs(text, { size: PT(11), italics: true }), alignment: AlignmentType.CENTER, keepNext: true, spacing: { line: 240, after: 80 } });

// ---------------------------------------------------------------- tables
const border = { style: BorderStyle.SINGLE, size: 4, color: '000000' };
const borders = { top: border, bottom: border, left: border, right: border };
function table(widths, header, rows, o = {}) {
  const cell = (t, w, head, align) => new TableCell({
    width: { size: w, type: WidthType.DXA }, borders, verticalAlign: VerticalAlign.CENTER,
    margins: { top: 40, bottom: 40, left: 90, right: 90 },
    shading: head ? { fill: 'D9D9D9', type: ShadingType.CLEAR, color: 'auto' } : undefined,
    children: [new Paragraph({ children: runs(t, { size: PT(11), bold: head }), alignment: align || AlignmentType.LEFT, spacing: { line: 240 } })],
  });
  const aligns = o.aligns || widths.map(() => AlignmentType.LEFT);
  return new Table({
    width: { size: widths.reduce((a, b) => a + b, 0), type: WidthType.DXA }, columnWidths: widths, alignment: AlignmentType.CENTER,
    rows: [
      new TableRow({ tableHeader: true, cantSplit: true, children: header.map((t, i) => cell(t, widths[i], true, aligns[i])) }),
      ...rows.map((r) => new TableRow({ cantSplit: true, children: r.map((t, i) => cell(t, widths[i], false, aligns[i])) })),
    ],
  });
}
const tcaption = (label, text) => new Paragraph({
  children: [new TextRun({ text: label + ' ', bold: true, size: PT(11) }), ...runs(text, { size: PT(11) })],
  alignment: AlignmentType.JUSTIFIED, keepNext: true, spacing: { line: 240, before: 160, after: 80 },
});
const after = () => new Paragraph({ children: [], spacing: { after: 120 } });

// ---------------------------------------------------------------- equation
function equation(number) {
  const sub = (a, b) => new MathSubScript({ children: [new MathRun(a)], subScript: [new MathRun(b)] });
  const sum = (k) => new MathSum({ children: [sub('w', 'k')], subScript: [new MathRun('k=1')], superScript: [new MathRun('K')] });
  const lhs = sub('S', 'i');
  const term = new MathSum({ children: [sub('w', 'k'), sub('m′', 'ik')], subScript: [new MathRun('k=1')], superScript: [new MathRun('K')] });
  return new Paragraph({
    tabStops: [{ type: TabStopType.CENTER, position: TEXT_W / 2 }, { type: TabStopType.RIGHT, position: TEXT_W }],
    spacing: { line: 240, before: 80, after: 120 },
    children: [
      new TextRun({ text: '\t' }),
      new MathBlock({ children: [lhs, new MathRun('='), term, new MathRun(',    '), sum(), new MathRun('=1')] }),
      new TextRun({ text: `\t(${number})` }),
    ],
  });
}

// ---------------------------------------------------------------- content
const TITLE = 'A Natural-Language Geospatial Query and Site-Evaluation System on PostGIS';
const ABSTRACT = 'Geospatial analysis supports urban planning, retail strategy and infrastructure decisions, yet traditional GIS platforms demand expertise in spatial query languages and specialised software. Large language models (LLMs) can lower this barrier, but systems that let the model answer directly tend to hallucinate place names and coordinates, which makes their output unverifiable. This paper presents GeoQuery, a Felt-style layered web map driven by a natural-language to PostGIS query engine grounded in open data. An LLM writes a PostGIS query against a documented schema, the query is executed on real data, and the system returns a GeoJSON answer layer, a grounded explanation and the SQL itself, so every answer carries provenance. On top of the engine we build intelligent decision tools: a site report, a competition and catchment analysis, a cost-to-open and break-even estimator, and a side-by-side comparison of up to three candidate locations. The system runs on PostgreSQL 16 with PostGIS 3.4, Martin vector tiles and MapLibre GL, and is loaded with Mumbai data from OpenStreetMap, a 76,000-row house-price dataset and area-level crime data; its ETL is designed to generalise to other cities. We describe the architecture, the decision models and their limitations, and report a first benchmark of query accuracy on 39 spatial questions.';
const KEYWORDS = ['Generative AI', 'GIS', 'Natural Language Processing', 'PostGIS', 'Site Selection', 'Spatial SQL', 'Text-to-SQL']; // alphabetical

function body() {
  const c = [];
  // ---- 1 Introduction
  c.push(H1('1  Introduction'));
  c.push(P('Geospatial data is central to urban planning, transportation and retail analytics. Geographic Information Systems (GIS) have traditionally been the main tools for such analysis, but they require users to understand spatial data handling, query languages such as SQL, and specialised software, which is a barrier for the many people who have location questions but no GIS training.'));
  c.push(P('Web platforms such as Felt have made map creation and collaboration much easier [@felt], but users must still translate a real-world question into manual operations on layers and filters. LLMs have made natural-language interfaces to structured data practical, and recent work applies them to spatial data [@chatgeoai, @spatialt2s].'));
  c.push(P('A naive interface lets the LLM answer the question itself. Our first proof of concept (POC) did this and exposed three weaknesses: the model invented area names and coordinates, ranking used a fixed hand-weighted formula over about 40 areas with synthetic 1 to 10 metrics, and map markers were placed with random coordinate jitter on Leaflet raster maps with no real spatial computation. None of the outputs could be checked: the assistant answered with familiar area names, but nothing in the answer was computed from data.'));
  c.push(P('The central idea of this work is to replace “the LLM hallucinates the answer” with “the LLM writes a structured spatial query that is executed on real data”, so that every output is verifiable and reproducible and the generated SQL is shown as provenance.'));
  c.push(P('GeoQuery implements this idea as a full-screen layered map with a natural-language query bar, and supports decision-oriented work for prospective business owners: evaluating a clicked location, analysing local competition and catchment demand, estimating the cost to open a store, and comparing candidate sites. The main contributions are:', { keepNext: true }));
  c.push(...LIST('contrib', [
    'A natural-language to PostGIS query engine that grounds the LLM in a documented schema and returns a GeoJSON layer, an explanation and the executed SQL.',
    'A real-data foundation: an ETL pipeline that loads OpenStreetMap, real-estate listings and crime data into one spatial database, designed to work for any city.',
    'Decision tools (site evaluation, competition analysis, cost-to-open, location comparison) built on the same data.',
    'An honest account of what is and is not yet validated, with the evaluation plan for the missing pieces.',
  ]));
  c.push(P('The rest of the paper is organised as follows. Section 2 reviews related work. Section 3 describes the proposed system: the problem and objectives, the query engine, the decision models and the implementation. Section 4 presents the results, and Section 5 gives the conclusion, the limitations and the future scope.', { before: 60 }));

  // ---- 2 Literature survey
  c.push(H1('2  Literature Survey'));
  c.push(P('Traditional GIS platforms such as ArcGIS and QGIS provide buffering, proximity analysis and spatial querying, but assume knowledge of spatial concepts, data formats and query languages. Cloud platforms such as Felt and Mapbox improve collaboration and visualization [@felt], yet users still drive them through layers, filters and map controls.'));
  c.push(P('Natural-language interfaces to databases map a question to an executable query. Benchmarks such as Spider [@spider] and BIRD [@bird] have driven progress on general text-to-SQL, with LLM-based systems now dominating. Spatial questions add difficulty: the model must pick the right geometry types, apply spatial predicates and distance functions correctly, and respect coordinate reference systems. Early rule-based interfaces mapped keywords such as “near” and “within” to spatial operations, which works for simple queries but is brittle for ambiguous or compositional ones.'));
  c.push(P('More recent work uses LLMs for geospatial tasks. A multi-agent spatial text-to-SQL pipeline reports that an execution-based review stage improves accuracy by roughly 11 points [@spatialt2s], a result from that work and not from ours. ChatGeoAI converts natural language into executable geospatial operations for non-expert users [@chatgeoai], and we take these two as the design reference for our query engine. GeoLLM shows that LLMs combined with OpenStreetMap features can model quantities for which ground truth is scarce [@geollm], which we treat as relevant to estimating metrics such as rent where no direct data exists.'));
  c.push(P('Spatial decision support systems extend GIS with multi-criteria decision analysis (MCDA) for tasks such as site selection [@malczewski]. They rank candidates by combining normalised criteria with weights, but typically need expert configuration and interpretation.'));
  c.push(P('OpenStreetMap (OSM) provides free, globally available data on roads, amenities and land use [@osm], and OSMnx makes it easy to acquire polygon-bounded extracts for any city [@osmnx]. PostGIS adds spatial types, GiST indexing and spatial functions to PostgreSQL, a suitable execution target for generated queries. Existing systems tend to cover either visualization, query processing or decision support; we combine all three on one open-data stack, with the emphasis on verifiable query results.'));

  // ---- 3 Proposed system
  c.push(H1('3  Proposed System'));
  c.push(P('GeoQuery lets users ask questions about geospatial data in plain English and then act on the results with decision tools. Its workspace is a full-screen map with a layer panel, a natural-language query bar, and panels for evaluating, comparing and costing locations.'));
  c.push(P('Figure 1 gives an overview. A question goes from the browser to the FastAPI backend, where an LLM pipeline checks its intent, grounds it in the schema and generates a PostGIS query. The query is validated and executed, a correction loop retries it on an error or an empty result, and the rows are returned as a GeoJSON answer layer drawn by MapLibre GL. The stages are detailed in Section 3.2.', { keepNext: true }));
  c.push(center([svgImage(1, 'Architecture diagram: web application, FastAPI backend, LLM API, PostgreSQL with PostGIS, and the Martin tile server.')]));
  c.push(caption('Figure 1.', 'Architecture of GeoQuery. The web application sends a question to the FastAPI backend, which calls a hosted LLM for intent checking, SQL generation and the explanation, and queries a PostgreSQL/PostGIS database under a read-only role. The Martin tile server publishes the same database tables as vector tiles, which the web application draws.'));

  c.push(H2('3.1  Problem Statement and Objectives'));
  c.push(P('Geospatial analysis is essential for business planning, but existing GIS tools demand knowledge of spatial data and query languages and mostly leave users to interpret patterns by hand. A person deciding where to open a cafe must weigh prices, transit, safety, competition and start-up cost, and no single easy tool combines these. LLM interfaces lower the barrier, but when the model supplies the answer directly, place names and coordinates can be invented and nothing can be verified. A system is needed that accepts natural language, computes answers on real spatial data, shows how each answer was obtained, and supports practical location decisions.'));
  c.push(P('The objective is therefore a natural-language geospatial query and decision-support system that accepts plain English, translates it into PostGIS queries through an LLM grounded in a documented schema, returns a map layer with an explanation and the executed SQL, and supports location decisions (site evaluation, competition and catchment analysis, cost-to-open and break-even estimation, and side-by-side comparison), using only open-source tools and open data.'));

  c.push(H2('3.2  Methodology'));
  c.push(P('The system is a modular pipeline (Figure 2). A question enters through the query bar, the backend turns it into a spatial query, the database executes it, and the frontend draws the answer. Decision tools reuse the same database through dedicated endpoints. The steps are:', { keepNext: true }));
  c.push(...LIST('steps', [
    '**User input.** The user types a spatial question, either exploratory (“hospitals within 1 km of a metro station”) or decision-oriented.',
    '**Intent check.** A first LLM call decides whether the question is a clear spatial query and labels its task type (filter, proximity, ranking, aggregation, site selection or other). If the target is genuinely unknowable, for example “best place?”, the system returns a short follow-up question instead of running a query.',
    '**Schema grounding.** The SQL-generating call receives a compact description of the queryable schema in its prompt: the tables and columns of the `admin`, `roads`, `transport`, `poi`, `realestate`, `demo`, `crime` and `env` schemas, their geometry types and the allowed values of key categorical columns, plus rules to filter every table by `city_id`, use only listed tables and columns, and emit one read-only `SELECT` with a geometry column named `geom`. Because the model can only reference data that exists, it cannot invent places. The same description is stored as a 34-row `meta.schema_catalog` table, which the engine does not read at query time.',
    '**Query generation and validation.** The LLM (Groq `openai/gpt-oss-120b`) writes a PostGIS query using functions such as `ST_DWithin` and `ST_Contains` over EPSG:4326 geometry indexed with GiST. Before execution the text must be a single `SELECT` or `WITH` statement with no chained statements and no data-modifying or DDL keywords.',
    '**Execution and repair.** The query runs on PostgreSQL 16 with PostGIS 3.4 as a dedicated read-only role, with a 15 second statement timeout and a cap of 5,000 features. If it fails validation or raises a database error, the error text is fed back to the model for a corrected query (at most two repairs), and if a valid query returns no rows the model is asked once to loosen it. The best successful attempt is kept, preferring a non-empty one, and every attempt is returned to the client. This is a simplified form of the execution-based review in [@spatialt2s], with at most four attempts in total.',
    '**Result and visualization.** Rows become a GeoJSON answer layer, and the LLM writes a short explanation grounded in a sample of the returned rows; the generated SQL is returned alongside, so users can inspect how the answer was obtained. MapLibre draws the layer next to the base layers, which Martin serves as Mapbox Vector Tiles directly from PostGIS.',
  ]));
  c.push(center([svgImage(2, 'Pipeline diagram: question, intent check, SQL generation, validation, read-only execution with a retry loop, GeoJSON layer and explanation, map.')]));
  c.push(caption('Figure 2.', 'Pipeline of the natural-language query engine. A question passes an intent check and SQL generation, and the SQL is validated and executed under a read-only role. An error or an empty result (dashed arrow) sends the query back to generation for a bounded number of retries. The rows become a GeoJSON layer with an explanation and are drawn on the map.'));

  c.push(H2('3.3  Decision Support Models'));
  c.push(P('The decision tools reuse the same database through separate endpoints.'));
  c.push(P('**Site evaluation.** For a clicked point and a radius of 0.5 to 3 km, the report gives the median price per sq ft of nearby listings, a typical price band, a comparison with the city median, a breakdown by size band, the nearest metro, rail and bus stops, amenity counts (healthcare, education, food, banking, shopping), and a safety score with a risk level.'));
  c.push(P('**Competition and catchment analysis.** The report gives the competitor count, density (per km²), nearest competitor, a saturation label (below 5 low, 5 to 15 moderate, 15 to 30 high, above 30 saturated) and a 0 to 100 catchment demand index. Competitors are points in `poi.place` whose category matches the business type inside the radius. The demand index counts points of interest in five groups (healthcare, education, food, banking and shopping) and transit stops, caps each count (40, 25, 40, 15, 30 and 12 respectively) so that dense areas do not dominate, and combines them with business-specific weights. To suggest gaps, a 5 by 5 grid of candidate spots covers the radius, each scored as its demand index divided by one plus its competitors within 500 m; up to three spots with a demand index of at least 15 and a score at least 15% above the evaluated spot are suggested (green markers; competitors are red dots).'));
  c.push(P('**Cost-to-open and break-even.** The estimator takes a store area in sq ft and returns one-time setup costs, monthly running costs and working capital. Because rental data is not available, rent is estimated from sale prices: the median sale price per sq ft of listings within 2.5 km times 0.5% (a rent-to-value ratio) and a commercial premium of 1.15, or 120 rupees per sq ft per month if no listing is nearby. The security deposit is six months of rent and working capital is three months of running costs; other line items come from the LLM, with a heuristic fallback. Customers per day are the store area (per 100 sq ft) times a benchmark rate for the business type, a footfall multiplier of 0.6 to 1.5 (amenities within 1 km, metro or rail within 800 m) and a competition factor 1 / (1 + 0.04 __n__) floored at 0.6, where __n__ is the number of competitors within 1 km. Revenue is customers times an average ticket (scaled by 0.8, 1.0 or 1.3 by tier) times 30 days, and profit is revenue minus cost of goods (a fixed share of revenue) and the remaining monthly costs. The conservative, base and optimistic scenarios scale customers by 0.7, 1.0 and 1.3. Payback is the setup cost divided by monthly profit, and break-even revenue is the remaining monthly cost divided by one minus the cost-of-goods share. The per-type benchmarks are assumptions set by the authors, not measured values, and because the LLM line items vary, two runs for the same site can give different totals, profit and payback.'));
  c.push(P('**Location comparison.** Up to three pinned spots (A, B, C) are shown side by side across price, access, safety, competitors, rent, start-up cost, revenue, profit and payback. The best value in each row is marked.'));
  c.push(P('**Area-level weighted ranking (legacy dashboard).** The original dashboard ranks areas with a standard weighted-sum MCDA model [@malczewski]. For area __i__ with criteria __m__~ik~ (footfall, youth, access, rent and competition, each scored 0 to 10) the score is', { keepNext: true }));
  c.push(equation(1));
  c.push(P('where __m__′~ik~ = __m__~ik~ for benefit criteria (footfall, youth, access) and __m__′~ik~ = 10 − __m__~ik~ where lower is better (rent and competition). The hand-picked weights are 0.30, 0.25, 0.20, 0.15 and 0.10 in that order, and the five highest-scoring areas are returned. In the POC the metrics were synthetic.'));
  c.push(P('To test how much the ranking depends on these weights we ran a sensitivity study on the 40 scored areas. We compared the hand-picked weights with equal, rank-order centroid (ROC), AHP (consistency ratio 0.011), entropy and CRITIC weights, three scenario weight sets (budget, student and premium) and TOPSIS, measured agreement by Kendall’s τ and by the overlap of the top five areas, perturbed each weight by up to 30% one at a time, and drew 1,000 random weight vectors (seed 42). The results are given in Section 4.3.2.'));

  c.push(H2('3.4  Implementation'));
  c.push(P('GeoQuery has three layers: a presentation layer (React 19, Zustand and MapLibre GL), an application layer (FastAPI with the LLM client, and MongoDB for chat history only) and a data layer (PostgreSQL 16 with PostGIS 3.4, and Martin for vector tiles); Table 1 lists the components. This separation keeps the model, the query execution and the rendering independently replaceable. The database holds all layers in EPSG:4326 with GiST indexes and a `city_id` on every row, so several cities can coexist. The ETL ingests roads, transit, POIs and boundaries from OpenStreetMap by city polygon (OSMnx), geocodes 228 real-estate localities with Nominatim and loads the crime data, so the same pipeline can load other cities; the deployed instance is pre-loaded for Mumbai. The workspace has a layer panel with opacity sliders, click-to-inspect, a query bar, and an evaluation panel with Competition and Cost-to-open tabs. The original assistant dashboard (a chat assistant with a Leaflet heatmap that ranks areas) is kept as the baseline. The system uses open-source software and open data throughout.'));
  c.push(tcaption('Table 1.', 'Component stack of GeoQuery, by layer.'));
  c.push(table([1900, 7126], ['Layer', 'Components'], [
    ['**Presentation**', 'React 19, MapLibre GL, Zustand; layer panel, query bar, evaluation panel'],
    ['**Application**', 'FastAPI endpoints, LLM client (one module), MongoDB chat history'],
    ['**Tiles**', 'Martin serving Mapbox Vector Tiles from PostGIS'],
    ['**Data**', 'PostgreSQL 16 + PostGIS 3.4 + pgvector; schemas `admin`, `roads`, `transport`, `poi`, `realestate`, `demo`, `crime`, `env`; `meta.schema_catalog`; `core.city`'],
    ['**ETL**', 'OSMnx ingest, Nominatim geocoding, crime data migration'],
  ]));
  c.push(after());

  // ---- 4 Results
  c.push(H1('4  Results and Discussion'));
  c.push(H2('4.1  Implemented System'));
  c.push(P('The system is implemented end to end. Table 2 lists the Mumbai data that the current instance holds.', { keepNext: true }));
  c.push(tcaption('Table 2.', 'Mumbai data loaded in the current instance.'));
  c.push(table([6200, 2826], ['Dataset', 'Size'], [
    ['Administrative boundaries', '48'], ['Road segments', '16.8 thousand'], ['Transit stops', '2.2 thousand'],
    ['Businesses and points of interest', '10.8 thousand'], ['Real-estate listings (CSV rows)', '76,000'],
    ['Geocoded real-estate localities', '228'], ['Neighbourhoods with a safety score', '40'], ['Schema catalog entries', '34'],
  ], { aligns: [AlignmentType.LEFT, AlignmentType.RIGHT] }));
  c.push(after());
  c.push(P('Compared with the POC, the GeoQuery workspace replaces invented coordinates with coordinates from the database, replaces random marker jitter with real geometries, replaces raster Leaflet maps with vector tiles, and replaces fixed synthetic metrics with metrics computed from nearby listings, transit and amenities. One caveat applies: the real-estate listings have no coordinates of their own, so each is placed near the centre of its locality with a small deterministic offset of up to about 700 m, and values computed from listings are valid at the scale of a neighbourhood and not of a building.'));

  c.push(H2('4.2  Qualitative Demonstration'));
  c.push(P('A query such as “hospitals within 1 km of a metro station” is turned into a spatial SQL query, executed and drawn as an answer layer, with the explanation and the SQL in the panel. Clicking a location opens a site report, and the Competition and Cost-to-open tabs extend it to a business decision. Figure 3 shows this for a cafe at Vikhroli (B), compared with Kanjurmarg (A). The competition tab finds four cafes within 1.5 km, the nearest 1.3 km away, so neither site has a competitor within 1 km; the catchment demand index is 78 out of 100, and the tab suggests two lower-competition spots (green), one 1.4 km away with demand 54 and one 675 m away with demand 35, each with no competitor within 500 m.'));
  c.push(P('The comparison table puts measured site attributes next to modelled business figures. The measured rows differ in ways a decision maker can use: the nearest metro or rail stop is 719 m from B and 929 m from A, B has 172 amenities within 1.5 km against 46 for A, and A has the higher safety score (82 against 74). Both sites have about the same median price per sq ft (about 19,000 rupees) and neither has a competitor within 1 km. The modelled rows (rent, start-up cost, revenue, profit and payback) favour B in this run.'));
  c.push(center([jpgImage('fig_competition.jpg', 'Competition tab for a cafe at Vikhroli with competitors in red and suggested spots in green.', 470)]));
  c.push(subcap('(a) Competition tab'));
  c.push(center([jpgImage('fig_compare.jpg', 'Comparison table of Kanjurmarg and Vikhroli for a standard-tier cafe.', 310)]));
  c.push(subcap('(b) Comparison of two candidate spots'));
  c.push(caption('Figure 3.', 'Decision tools in the workspace for a cafe at Vikhroli, Mumbai. (a) Competition tab with a 1.5 km radius: competitors are red dots, suggested lower-competition spots are green markers, and the side panel shows the catchment demand index and the nearest competitors. (b) Comparison of Kanjurmarg (A) and Vikhroli (B) for a standard-tier cafe. The site rows are measured within 1.5 km; rent, start-up cost, revenue, profit and payback are modelled estimates from a single run.'));
  c.push(P('The cost-to-open tab produces a full business plan. Table 3 and Table 4 give the values of the plan that the tool generated for an 800 sq ft standard-tier cafe at Vikhroli. The rent line (96,724 rupees per month) is derived from the sale prices of 3,410 nearby listings, and the report states that it is a derived value and not a listed rent.', { keepNext: true }));
  c.push(tcaption('Table 3.', 'Capital needed to start the cafe in the generated plan (rupees; single run).'));
  c.push(table([6200, 2826], ['Item', 'Amount (rupees)'], [
    ['One-time setup (deposit, fit-out, furniture, equipment, stock, licences, branding)', '51,20,344'],
    ['Monthly running cost (rent, staff, utilities, restock, marketing)', '4,81,224'],
    ['Working capital (three months of running cost)', '14,43,672'],
    ['**Total capital to start**', '**65,64,016**'],
  ], { aligns: [AlignmentType.LEFT, AlignmentType.RIGHT] }));
  c.push(after());
  c.push(tcaption('Table 4.', 'Modelled revenue scenarios of the same plan (single run). Break-even needs about 4,73,177 rupees of revenue per month, or about 53 customers per day at a 300 rupee average ticket.'));
  c.push(table([2200, 1500, 1800, 1800, 1726], ['Scenario', 'Customers/day', 'Revenue/month (rupees)', 'Profit/month (rupees)', 'Payback'], [
    ['Conservative', '81', '7,31,808', '1,81,042', '28.3 months'],
    ['Base', '116', '10,45,440', '4,00,584', '12.8 months'],
    ['Optimistic', '151', '13,59,072', '6,20,126', '8.3 months'],
  ], { aligns: [AlignmentType.LEFT, AlignmentType.RIGHT, AlignmentType.RIGHT, AlignmentType.RIGHT, AlignmentType.RIGHT] }));
  c.push(after());
  c.push(P('The plan also shows a limitation. The summary paragraph under the headline figures is written by the LLM, and in this run it quotes an upfront capital of about 4.5 million rupees and monthly expenses of about 240,000 rupees plus payroll, which do not match the itemised totals above (51.2 lakh and 4.8 lakh). The itemised lines are the ones the program sums; the text is not reconciled with them. The plan comes from a different run than the comparison in Figure 3, so its start-up cost and payback differ from the Vikhroli column there (65.6 lakh and 12.8 months here, 49.9 lakh and 9.1 months there). The size of that difference, with a similar rent in both runs, is consistent with the run-to-run variability of the LLM-produced line items, and it is why we treat the measured site attributes as more reliable than the modelled business figures.'));

  c.push(H2('4.3  Comparative Analysis'));
  c.push(P('We compare the system along two axes: the query engine against its own ablations and against the direct-LLM approach of the POC, and the weighting schemes of the legacy area ranking.'));
  c.push(H3('4.3.1  Query engine versus ablations and the direct-LLM baseline'));
  c.push(P('The benchmark has 39 spatial questions in six categories (filters, proximity, named areas, rankings, listings and compositional queries), each with a hand-written gold SQL query. A predicted layer is scored by comparing its geometry set with the executed gold result (exact match and F1), so column names do not matter. Three configurations are compared: the full engine; the same engine restricted to its first generation attempt (the first SQL of each full run, re-executed, which makes a paired comparison); and a direct-LLM baseline in which the model names places and coordinates without a database. The baseline returns no SQL, so it is scored on grounding: the share of returned names that exist in the database and the share of returned points near a real feature. Results are from a single run with `openai/gpt-oss-120b` and default sampling; the intent-check and explanation calls were skipped because they do not change the SQL.'));
  c.push(tcaption('Table 5.', 'Benchmark results on 39 questions, single run. “Exact” is the share of questions whose result equals the gold layer.'));
  c.push(table([4426, 1500, 1700, 1400], ['Configuration', 'Exact', 'Geometry F1', 'Executed'], [
    ['Full engine', '74.4%', '88.4%', '100%'], ['First attempt only (no repair)', '74.4%', '88.4%', '100%'],
  ], { aligns: [AlignmentType.LEFT, AlignmentType.CENTER, AlignmentType.CENTER, AlignmentType.CENTER] }));
  c.push(after());
  c.push(P('The full engine returns exactly the gold layer for 29 of the 39 questions (74.4%, geometry F1 88.4%), and every generated query executed and returned rows (Table 5, Figure 4). The repair stage was never triggered, so the first-attempt-only configuration scores identically and this benchmark shows no benefit from repair. Accuracy is highest for named-area and ranking questions (both 100%) and lowest for listings (25%). Eight of the ten failures come from a row cap and not from a wrong query: the schema notes tell the model to use `LIMIT 500`, so questions whose gold answer is larger than 500 rows are truncated, and joined queries without `DISTINCT` let duplicate rows use up the limit. The other two are over-inclusive category choices (universities matched together with colleges, and motorways with a pattern broader than the gold road class). We count all ten as failures, but they point to the prompt rules and to the exact-match scoring more than to a lack of spatial reasoning.', { keepNext: false }));
  c.push(center([svgImage(3, 'Bar chart of exact-match accuracy by question category for the full engine and the no-repair configuration.')]));
  c.push(caption('Figure 4.', 'Exact-match accuracy of the query engine by question category on the 39-question benchmark (filter 10, proximity 9, named area 7, ranking 3, listing 4 and compositional 6 questions). The first-attempt-only configuration equals the full engine because no query needed a repair.'));
  c.push(P('The direct-LLM baseline gives a very different picture (Figure 5). Only 19.5% of the place names it returned exist in the database, 57.0% of its coordinates lie within 150 m of some real feature, and only 10.6% lie within 200 m of a feature in the gold answer. The coordinate figure is generous, because Mumbai is dense and a random point is often near some point of interest, so the other two figures are more informative. The baseline returns no SQL, so none of its answers can be checked. The median latency of the engine was 4.5 s, with a 95th percentile of 13.8 s (one LLM call plus the database, without the intent-check and explanation stages), against 13.2 s for the baseline. With 39 questions and one run, differences of a few questions should not be over-interpreted. A further ablation, in which the schema description lists only table names, is implemented but was not run.'));
  c.push(center([svgImage(4, 'Bar chart: share of baseline names in the database, points near a real feature and near a gold feature, next to the engine geometry F1.')]));
  c.push(caption('Figure 5.', 'Grounding of the direct-LLM baseline compared with the engine. The three left bars show the share of names the baseline returned that exist in the database (19%), the share of its returned points within 150 m of some real feature (57%) and within 200 m of a feature in the gold answer (11%). The right bar is the geometry F1 of the engine against the gold layer (88%). The metrics differ, so the bars are not directly comparable.'));

  c.push(H3('4.3.2  Weighting schemes of the legacy ranking'));
  c.push(P('The ranking is stable under small changes to a single weight (worst-case τ of 0.90 or higher for a 30% change, lowest for the access weight; Figure 7) but not under a change of scheme (Figure 6). AHP, ROC and the premium scenario keep the baseline’s top five (τ of 0.92, 0.81 and 0.83), while equal weights, entropy weights, the student scenario, the budget scenario, TOPSIS and CRITIC share only 2, 2, 2, 1, 1 and 0 of its top five areas (τ of 0.41, 0.58, 0.87, −0.11, 0.36 and −0.01). Across random weight vectors the median τ is 0.33 (5th to 95th percentile −0.49 to 0.84), and no area stays in the top five in more than 45% of draws. The weights therefore encode a preference, not a neutral measurement, which is one reason the GeoQuery workspace uses measured spatial queries in place of this fixed ranking. These results describe the 40-area scored dataset, not real-world site quality.'));
  c.push(center([svgImage(5, 'Horizontal bar chart of Kendall tau for each alternative weighting scheme against the hand-picked weights.')]));
  c.push(caption('Figure 6.', 'Rank agreement (Kendall’s τ) of each alternative weighting scheme with the hand-picked weights of the legacy ranking. The bracket after each value shows how many of the baseline’s top-five areas the scheme shares; the bar colour marks whether the top five is the same, partly different or without agreement.'));
  c.push(center([svgImage(6, 'Line chart of Kendall tau against the change in one criterion weight, for five criteria.')]));
  c.push(caption('Figure 7.', 'One-at-a-time sensitivity of the legacy ranking. Kendall’s τ against the hand-picked ranking when one criterion’s weight is changed by up to 30% (the others renormalised), for each of the five criteria. τ stays at 0.90 or above.'));

  c.push(H2('4.4  Discussion'));
  c.push(P('Grounding the model in a documented schema and returning the executed SQL changes the nature of the interface: answers can be checked, reproduced and corrected, and the decision tools show that the same data supports practical questions, such as comparing three candidate shop locations on price, access, safety and competition.'));
  c.push(P('The main weakness is evaluation. The benchmark is small, was run once and did not exercise the repair stage, so we cannot say how much repair helps or how the engine behaves on harder questions, and the safeguards (a read-only role, a statement timeout, a row cap and a single-statement check) have not been tested against adversarial input. Cost and revenue estimates inherit the approximations in the rent model, the benchmarks and the LLM line items, so the measured site attributes are more reliable than the modelled business figures and the estimates should be treated as planning aids. The weight study shows that the legacy area ranking is sensitive to the choice of weighting scheme.'));

  // ---- 5 Conclusion
  c.push(H1('5  Conclusion and Future Scope'));
  c.push(H2('5.1  Conclusion'));
  c.push(P('GeoQuery shows that a natural-language interface to geospatial data can be built so that answers are computed on real data and are inspectable. By pairing a schema-grounded LLM with PostGIS, vector tiles and open data, it avoids the invented places and coordinates of direct LLM answers, and it extends the query engine with site evaluation, competition analysis, cost-to-open modelling and location comparison. The system is functional for Mumbai, and its ETL is designed to generalise. A first benchmark of 39 questions shows 74.4% exact-match accuracy against hand-written gold queries, with most failures caused by a row cap, whereas a direct-LLM baseline returns real place names only 19.5% of the time. A larger benchmark remains to be built.'));
  c.push(H2('5.2  Limitations'));
  c.push(...LIST('limits', [
    '**Small benchmark.** The NL to SQL benchmark has 39 questions in six categories and was run once, so its accuracy figures carry substantial uncertainty. No query needed a retry, so the benefit of the repair stage is unmeasured.',
    '**Basic SQL safeguards.** Generated SQL runs under a read-only role with a statement timeout and a row cap and is checked to be a single `SELECT`. The check is keyword-based and not a full SQL parser, and there is no table allow-list beyond the role’s grants. The LLM is called without a fixed temperature, so the same question can yield different SQL.',
    '**Modelled business figures.** There is no real rental data, so rent is estimated from sale prices. The saturation bands, demand weights and per-type revenue benchmarks are set by judgement and not calibrated against real outcomes. The non-rent cost items and the report summary are written by the LLM and not reconciled with the computed totals, so totals, profit and payback can differ between runs for the same site and the summary can disagree with the figures beside it.',
    '**Coarse spatial data.** Real-estate listings are placed at locality level (228 localities) with a small offset, catchments are circles and not travel-time isochrones, crime data is area-level, and OSM completeness varies.',
    '**Coverage and usability.** Only Mumbai is loaded. Pinned locations are not saved, and the interface is designed for desktop.',
  ]));
  c.push(H2('5.3  Future Scope'));
  c.push(...LIST('future', [
    '**Query reliability:** extend the benchmark (more questions, repeated runs, other models and harder queries that exercise the repair stage) in the style of Spider and BIRD [@spider, @bird, @spatialt2s], remove the row-cap and over-inclusion failures found here, and replace the keyword check with parser-based validation and a table allow-list.',
    '**Data and models:** integrate real rental data, calibrate the saturation bands and revenue benchmarks against real outcomes, fix or cache the LLM cost items per site so that repeated runs agree, and extend the metrics modelling with LLM and OSM features where ground truth is scarce [@geollm].',
    '**Coverage and usability:** replace radius catchments with isochrones, load additional cities using the existing ETL, and add saved sites and a mobile layout.',
  ]));
  return c;
}

function references() {
  const c = [new Paragraph({ children: [new TextRun({ text: 'References' })], heading: HeadingLevel.HEADING_1, keepNext: true, spacing: { before: 240, after: 120 } })];
  REFS.forEach((r, i) => {
    const kids = [new TextRun({ text: `${i + 1}.\t` }), ...runs(r.text)];
    if (r.doi) kids.push(new ExternalHyperlink({ link: 'https://doi.org/' + r.doi, children: [new TextRun({ text: 'https://doi.org/' + r.doi, style: 'Hyperlink' })] }));
    if (r.url) kids.push(new ExternalHyperlink({ link: r.url, children: [new TextRun({ text: r.url, style: 'Hyperlink' })] }));
    c.push(new Paragraph({ children: kids, alignment: AlignmentType.LEFT, indent: { left: 454, hanging: 454 }, tabStops: [{ type: TabStopType.LEFT, position: 454 }], spacing: { line: 240, after: 80 } }));
  });
  return c;
}

// ---------------------------------------------------------------- front matter
function frontAnonymous() {
  return [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120, line: 240 }, children: [new TextRun({ text: TITLE, bold: true, size: PT(14) })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 240, line: 240 }, children: [new TextRun({ text: 'Anonymous authors (removed for double-blind review)', italics: true })] }),
  ];
}
function frontTitlePage() {
  const L = (t, o = {}) => new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: o.after === undefined ? 60 : o.after, line: 240 }, children: [new TextRun({ text: t, size: PT(14), bold: !!o.bold, superScript: !!o.sup })] });
  const people = [
    ['Vaishali Wadhe', 'vwadhe@somaiya.edu'], ['Riddhesh Chaudhary', 'riddhesh.c@somaiya.edu'],
    ['Arpit Balmiki', 'arpit.b@somaiya.edu'], ['Chirayu Vyas', 'chirayu.vyas@somaiya.edu'],
  ];
  return [
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 200, line: 240 }, children: [new TextRun({ text: TITLE, bold: true, size: PT(14) })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120, line: 240 }, children: people.flatMap(([n], i) => [
      new TextRun({ text: n, bold: true, size: PT(14) }), new TextRun({ text: '1', bold: true, size: PT(14), superScript: true }),
      new TextRun({ text: i < people.length - 1 ? ', ' : '', bold: true, size: PT(14) })]) }),
    L('^1^ Department of Artificial Intelligence and Data Science,'.replace('^1^ ', '1 '), { after: 0 }),
    L('K.J. Somaiya Institute of Technology, Sion Ayurvihar Complex, Eastern Express Highway,'),
    L('Everard Nagar, Sion East, Mumbai - 400022, India'),
    ...people.map(([n, e]) => L(`${n}: ${e}   |   Contact: [phone number]`)),
    new Paragraph({ children: [], spacing: { after: 160 } }),
  ];
}
function abstractBlock() {
  return [
    new Paragraph({ children: [new TextRun({ text: 'Abstract.', bold: true })], keepNext: true, spacing: { line: 240, after: 60 } }),
    new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: { line: 240, after: 120 }, children: [new TextRun({ text: ABSTRACT, italics: true })] }),
    new Paragraph({ alignment: AlignmentType.JUSTIFIED, spacing: { line: 240, after: 120 }, children: [new TextRun({ text: 'Keywords: ', bold: true }), new TextRun({ text: KEYWORDS.join(', ') })] }),
  ];
}

// ---------------------------------------------------------------- document
function makeDoc(variant) {
  const anon = variant === 'anonymous';
  const numbering = { config: ['contrib', 'steps', 'limits', 'future'].map((ref) => ({
    reference: ref,
    levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 567, hanging: 340 } } } }],
  })) };
  return new Document({
    creator: anon ? 'Anonymous' : '', lastModifiedBy: anon ? 'Anonymous' : '', title: TITLE, description: '', keywords: '',
    styles: {
      default: { document: { run: { font: FONT, size: PT(12) } } },
      paragraphStyles: [
        { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: PT(14), bold: true }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 0 } },
        { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: PT(12), bold: true }, paragraph: { spacing: { before: 160, after: 80 }, outlineLevel: 1 } },
        { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: FONT, size: PT(12), bold: true, italics: true }, paragraph: { spacing: { before: 120, after: 60 }, outlineLevel: 2 } },
      ],
      characterStyles: [{ id: 'Hyperlink', name: 'Hyperlink', basedOn: 'DefaultParagraphFont', run: { color: '0563C1', underline: { type: 'single' } } }],
    },
    numbering,
    sections: [{
      properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } } },
      footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: PT(11) })] })] }) },
      children: [...(anon ? frontAnonymous() : frontTitlePage()), ...abstractBlock(), ...body(), ...references()],
    }],
  });
}

(async () => {
  const outs = [['anonymous', 'ICDMAI_paper_anonymous.docx'], ['title', 'ICDMAI_paper_with_title_page.docx']];
  for (const [v, name] of outs) {
    const buf = await Packer.toBuffer(makeDoc(v));
    fs.writeFileSync(path.join(ROOT, name), buf);
    console.log('wrote', name, buf.length, 'bytes');
  }
})();
