// ============================================================================
//  CONFIG — fill in YOUR project details here.
//  Every cover, certificate, approval page and the spine read from this file.
//
//  Items written in [square brackets] are PLACEHOLDERS: details only the team
//  knows. Replace them before printing.
// ============================================================================

// --- Project -----------------------------------------------------------------
#let Title = "Geospatial Query System with Natural Language Processing and GIS Integration"
#let Stream = "Artificial Intelligence & Data Science"
#let Stream-Short = "AI-DS"  // printed on the spine, e.g. AI-DS 2026-27/Group-3

#let Group-Number = "1"  // PLACEHOLDER: your group number (printed on the spine)

// --- Students ----------------------------------------------------------------
// One line per student: (Name, Roll Number, Division, Exam Seat Number)
// Only the name and the exam seat number are printed in the book.
#let dataset = (
  ("Riddhesh Chaudhary", "[roll no.]", "L.Y. - A", "[seat no.]"),
  ("Arpit Balmiki", "[roll no.]", "L.Y. - A", "[seat no.]"),
  ("Chirayu Vyas", "[roll no.]", "L.Y. - B", "[seat no.]"),
)

// --- Guides ------------------------------------------------------------------
#let Supervisor-1 = "Dr. Vaishali Wadhe"
#let Supervisor-1-Designation = "Dean-Industry & Institute Interaction Cell"  // PLACEHOLDER
#let Supervisor-1-Dept = "AI&DS"

#let Supervisor-2 = ""  // No second guide. Set a name here if one is assigned.
#let Supervisor-2-Designation = ""
#let Supervisor-2-Dept = ""

// --- Signatories -------------------------------------------------------------
#let HOD-name = "Dr. Milind Nemade"

#let Principal-name = "Dr. Vivek Sunnapawar"

// --- College (printed at the bottom of the covers) ---------------------------
#let College-Name = "K.J. Somaiya Institute of Technology"
#let College-Address = "Sion Ayurvihar Complex, Eastern Express Highway, Everard Nagar, Sion East, Mumbai-400022"
#let Year = "2026"

// --- Chapters ----------------------------------------------------------------
// Listed in the order they appear in the book.
// To add a chapter: create a file in content/chapters/ and add its path here.
// (The four tutorial chapters 01-getting-started ... 04-citing-references are no
//  longer listed. The files are still in content/chapters/ for reference.)
#let chapters = (
  "/content/chapters/10-introduction.typ",
  "/content/chapters/20-literature-survey.typ",
  "/content/chapters/30-proposed-system.typ",
  "/content/chapters/40-implementation.typ",
  "/content/chapters/50-results-and-discussion.typ",
  "/content/chapters/60-conclusion.typ",
)
