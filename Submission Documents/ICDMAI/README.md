# ICDMAI 2027 submission

Paper for the **11th International Conference on Data Management, Analytics & Innovation (ICDMAI 2027)**,
15–17 January 2027, Bengaluru, India. Springer publication (indexed in Scopus, Web of Science, ISI);
organised by the Society for Data Science (S4DS). Submissions go through EasyChair:
<https://easychair.org/conferences/?conf=icdmai2027>.

Guidelines read from <https://www.icdmai.org/paper_submission> on 2026-10-24. The site publishes
**no submission deadline yet** ("check the conference website for key dates"; the schedule page says TBD).

## Files

| File | Use |
|---|---|
| `ICDMAI_paper_anonymous.docx` | **The file to upload for review.** No author names, affiliations or contacts. |
| `ICDMAI_paper_with_title_page.docx` | Same paper with the required title page (names, affiliation, emails, contact numbers). For the camera-ready stage or if the organisers ask for it. |
| `figures/` | Figures as `fig-N.svg` (vector, text as outlines) with `fig-N.png` (300 ppi) fallbacks. Sources in `figures/source/`. |
| `images/` | The two screenshots used in Figure 3. |
| `build/build.js` | Script that generates both Word files. |

Rebuild: `typst compile --format svg figures.typ "../fig-{0p}.svg"` (and `--format png --ppi 300`) in
`figures/source/`, then `npm install docx` and `node build.js` in `build/`.

## Guidelines and how the paper meets them

| Requirement (from the site) | What was done | Status |
|---|---|---|
| MS Word compatible, single column, single line spacing | `.docx`, one column, line spacing 1.0 | Met |
| 12 pt Times New Roman, 1-inch margins on all sides, A4 | 12 pt Times New Roman body, 2.54 cm margins, A4 | Met |
| Length: 10–14 A4 pages (introduction, literature survey, proposed work, results; excluding bibliography and appendices) | 13 pages in Word including the references | Met |
| Abstract 100–300 words, in italics; EasyChair accepts at most 300 | 204 words, italic | Met |
| Keywords after the abstract, alphabetical | Generative AI, GIS, Natural Language Processing, PostGIS, Site Selection, Spatial SQL, Text-to-SQL | Met |
| Figures labelled "Figure 1", "Figure 2", with complete captions that stand alone | 7 figures, captions rewritten to be self-contained | Met |
| References: title, journal, volume, year, pages | All 9 give title, venue, year and pages where they exist; DOIs are links | Met (see decision 2) |
| Title page: title, author names (bold), addresses, emails, contact numbers, affiliations, Times New Roman 14 pt | In `ICDMAI_paper_with_title_page.docx`, all 14 pt, names bold | Met, but see decision 1 |
| Double-blind review; non-anonymous papers are rejected without review | The upload file carries no names, affiliation, acknowledgements or institution-specific text; the document properties author is set to "Anonymous" | Met, but see decision 1 |

## Decisions that need you

1. **Anonymity versus title page.** The site asks for a title page with all author details *and* says
   non-anonymous papers are rejected unredacted. We read this as: upload the anonymous file for review, and
   give the title-page details at camera-ready (or in the EasyChair author fields). If the organisers want the
   title page inside the first upload, that contradicts their own double-blind rule, so ask them first
   (info@icdmai.org, +91 9836065470).
2. **Reference order.** The site says "list chronologically by first author name", which is ambiguous.
   References are ordered **alphabetically by the first author's surname** and numbered in that order.
   If they mean oldest first, the order is easy to change.
3. **Track.** Track 3, *Data Science & Analytics*, lists "Geospatial Data Analysis" as a topic, which is the
   closest fit. Track 4 (AI for Interdisciplinary Studies; includes "AI for Smart Cities") is the alternative.
4. **Contact numbers** on the title page are placeholders (`[phone number]`).
5. **Captions and tables** are 11 pt (body is 12 pt) for readability. The guideline only states 12 pt for the
   text; change `size: PT(11)` in `build/build.js` if you want them at 12 pt.

## Before uploading

- In Word, run **File > Info > Inspect Document** and remove personal information, so that saving the file in
  Word does not add your name to the properties.
- Check the screenshots (Figure 3) for anything that identifies the authors or institution.
- Confirm the similarity/plagiarism check policy with the organisers; the site does not state a limit.
