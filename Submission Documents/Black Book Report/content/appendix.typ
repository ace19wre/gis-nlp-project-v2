// ============================================================================
//  APPENDICES
//  Each = heading starts a new appendix, numbered automatically (A1, A2, ...).
// ============================================================================

#show figure: set block(breakable: true)

= Schema Description Given to the SQL Agent

This is the description of the queryable schema, with its rules, that is written into the prompt of the SQL-generating call (Chapter 3). The placeholder for the city identifier is replaced by the identifier of the city that is queried.

#figure(
  ````text
All tables are in PostGIS, geometry column is `geom`, SRID 4326. Every feature table has
`city_id` — ALWAYS filter `city_id = :CITY_ID` on every table you read.

admin.boundary(name text, admin_level int, kind text /*city|ward*/, geom MultiPolygon)
roads.segment(name text, highway_class text /*motorway|trunk|primary|secondary|tertiary*/,
              maxspeed int, oneway bool, geom LineString)
transport.stop(name text, mode text /*bus|metro|rail|tram*/, geom Point)
poi.place(name text, category text, tags jsonb, geom Point)
   -- THE ONLY table of businesses/amenities. category examples: restaurant, cafe, fast_food,
   --   bar, bank, atm, hospital, clinic, doctors, pharmacy, school, college, university,
   --   police, fire_station, fuel, marketplace, cinema, place_of_worship, hotel, museum, shop
realestate.listing(locality text, bhk int, type text, area_sqft float, price float,
              price_unit text /*'Cr'=crore, 'L'=lakh*/, status text, age text, geom Point)
demo.cell(population float, density float, age_median float, income_index float, geom Polygon)
crime.area(name text, zone text, safety_score int /*0-100, higher=safer*/,
              risk_level text /*low|medium|high*/, breakdown jsonb, geom Point)
   -- ALSO a NEIGHBOURHOOD GAZETTEER: ~40 point rows named like 'Bandra West', 'Andheri East',
   --   'Powai', 'Lower Parel'. Use it to resolve colloquial area names to a location.
env.measurement(kind text /*aqi|flood_risk*/, value float, geom Geometry)

CRITICAL GROUNDING:
- Businesses/amenities (hospital, cafe, bank, school, pharmacy...) live ONLY in poi.place via
  `category`. transport.stop.mode is ONLY 'bus'|'metro'|'rail'|'tram' — NEVER an amenity.
- admin.boundary ward names are coded ('K/W Ward', 'H/E Ward') and do NOT contain neighbourhood
  names. To find things "in <area>" (e.g. "in Bandra"), resolve the area via crime.area:
    JOIN crime.area a ON a.name ILIKE '%Bandra%'
    AND ST_DWithin(p.geom::geography, a.geom::geography, 2000)   -- ~2 km around the area
- "hospital" -> category IN ('hospital','clinic','doctors'); "college/university" likewise.

RULES:
- Output ONE read-only SELECT statement. No INSERT/UPDATE/DELETE/DDL, no semicolons chaining.
- Select a geometry column ALIASED EXACTLY `geom` (SRID 4326) plus useful descriptive columns
  (name, category, price, safety_score, ...). The `geom` column is required for mapping.
- Metric distance: use geography casts, e.g.
    ST_DWithin(a.geom::geography, b.geom::geography, 1000)   -- within 1000 metres
- Match names/categories with ILIKE '%...%'. When ranking, use ORDER BY + LIMIT (<= 500).
- Never reference a table or column not listed above.
  ````,
  caption: [Schema description and rules in the SQL-generation prompt],
)

= Database Definition (Excerpt)

An excerpt of the SQL that creates the database. It shows five of the tables of Chapter 3 and the grants of the read-only role that executes generated queries.

#figure(
  ````sql
CREATE TABLE core.city (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        TEXT NOT NULL,
    country     TEXT,
    centroid    geometry(Point, 4326),
    bbox        geometry(Polygon, 4326),
    ingested_at TIMESTAMPTZ,
    status      TEXT NOT NULL DEFAULT 'pending',   -- pending | ingesting | ready | error
    UNIQUE (name, country)
);

CREATE TABLE poi.place (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_id   BIGINT NOT NULL REFERENCES core.city(id) ON DELETE CASCADE,
    name      TEXT,
    category  TEXT,                                -- restaurant | bank | hospital | store | ...
    tags      JSONB,
    geom      geometry(Point, 4326)
);

CREATE TABLE realestate.listing (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_id    BIGINT NOT NULL REFERENCES core.city(id) ON DELETE CASCADE,
    locality   TEXT,
    bhk        INT,
    type       TEXT,
    area_sqft  DOUBLE PRECISION,
    price      DOUBLE PRECISION,
    price_unit TEXT,
    status     TEXT,
    age        TEXT,
    geom       geometry(Point, 4326)
);

CREATE TABLE crime.area (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city_id      BIGINT NOT NULL REFERENCES core.city(id) ON DELETE CASCADE,
    name         TEXT,
    zone         TEXT,
    safety_score INT,
    risk_level   TEXT,
    breakdown    JSONB,
    geom         geometry(Point, 4326)
);

CREATE TABLE meta.schema_catalog (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name  TEXT NOT NULL,
    column_name TEXT NOT NULL,
    data_type   TEXT,
    is_geometry BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    embedding   vector(768),
    UNIQUE (schema_name, table_name, column_name)
);
  ````,
  caption: [Definition of five tables],
)

#figure(
  ````sql
GRANT CONNECT ON DATABASE geo TO geo_readonly;

GRANT USAGE ON SCHEMA core, admin, roads, transport, poi, realestate, demo, crime, env, meta
    TO geo_readonly;

GRANT SELECT ON ALL TABLES IN SCHEMA
    core, admin, roads, transport, poi, realestate, demo, crime, env, meta
    TO geo_readonly;
  ````,
  caption: [Grants of the read-only role used for generated queries],
)

= Benchmark Questions

The 39 questions of the benchmark in Chapter 5, with the outcome of the full engine in the single run: 29 of 39 returned exactly the gold layer. Every question has a hand-written gold SQL query; the expected answer is the executed result of that query.

#figure(
  table(
    columns: (1.3cm, 3.2cm, 2cm, 1fr, 1.9cm),
    inset: 4pt,
    align: (center + horizon, left + horizon, left + horizon, left + horizon, center + horizon),
    stroke: 0.5pt,
    table.header([*ID*], [*Category*], [*Difficulty*], [*Question*], [*Exact match*]),
    [F01], [Filter], [Easy], [Show all pharmacies in the city.], [Yes],
    [F02], [Filter], [Easy], [Where are the cinemas?], [Yes],
    [F03], [Filter], [Easy], [List all police stations.], [Yes],
    [F04], [Filter], [Easy], [Show fuel stations.], [Yes],
    [F05], [Filter], [Easy], [Find all universities.], [No],
    [F06], [Filter], [Easy], [Show every hotel.], [Yes],
    [F07], [Filter], [Easy], [Show all hospitals.], [No],
    [F08], [Filter], [Easy], [Where are the metro stops?], [Yes],
    [F09], [Filter], [Easy], [Show the fire stations.], [Yes],
    [F10], [Filter], [Easy], [Show the motorways.], [No],
    [P01], [Proximity], [Medium], [Cafes within 500 m of a metro station.], [Yes],
    [P02], [Proximity], [Medium], [Hospitals within 1 km of a railway station.], [No],
    [P03], [Proximity], [Medium], [Banks within 300 m of a bus stop.], [No],
    [P04], [Proximity], [Medium], [Pharmacies within 200 m of a hospital.], [Yes],
    [P05], [Proximity], [Medium], [Schools within 500 m of a metro station.], [Yes],
    [P06], [Proximity], [Medium], [Metro stops within 1 km of a university.], [Yes],
    [P07], [Proximity], [Medium], [Restaurants within 250 m of a cinema.], [Yes],
    [P08], [Proximity], [Medium], [ATMs within 200 m of a railway station.], [Yes],
    [P09], [Proximity], [Medium], [Bus stops within 300 m of a police station.], [Yes],
    [A01], [Area], [Medium], [Cafes in Bandra.], [Yes],
    [A02], [Area], [Medium], [Pharmacies in Andheri.], [Yes],
    [A03], [Area], [Medium], [Banks in Powai.], [Yes],
    [A04], [Area], [Medium], [Schools in Borivali.], [Yes],
    [A05], [Area], [Medium], [Restaurants in Colaba.], [Yes],
    [A06], [Area], [Medium], [Hospitals in Dadar.], [Yes],
    [A07], [Area], [Medium], [Which metro stops are in Ghatkopar?], [Yes],
    [R01], [Ranking], [Medium], [Which 5 areas are the safest?], [Yes],
    [R02], [Ranking], [Medium], [Show the 3 least safe areas.], [Yes],
    [R03], [Ranking], [Medium], [Top 8 areas by safety score.], [Yes],
    [L01], [Listing], [Medium], [Listings with 3 or more bedrooms under 1 crore.], [Yes],
    [L02], [Listing], [Medium], [Listings larger than 3000 sqft.], [No],
    [L03], [Listing], [Medium], [Ready-to-move listings under 50 lakh.], [No],
    [L04], [Listing], [Medium], [Listings priced above 5 crore.], [No],
    [C01], [Compositional], [Hard], [Cafes within 500 m of a metro station that are also within 300 m of a bank.], [Yes],
    [C02], [Compositional], [Hard], [Areas with a safety score above 70 that have a metro stop within 2 km.], [Yes],
    [C03], [Compositional], [Hard], [Areas with no hospital within 500 m.], [Yes],
    [C04], [Compositional], [Hard], [Schools in Bandra that are within 500 m of a bus stop.], [No],
    [C05], [Compositional], [Hard], [Hospitals within 1 km of both a metro station and a railway station.], [No],
    [C06], [Compositional], [Hard], [The 3 safest areas that have a metro stop within 2 km.], [Yes],
  ),
  caption: [Benchmark questions and the result of the full engine],
)
