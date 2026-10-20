// Side-by-side: current PNG (left) against the Lilaq version (right), both at the
// width they get in the paper (one IEEE column, about 8.9 cm).
// Compile from this folder with:  typst compile --root .. compare.typ compare.pdf
#import "figs.typ": *

#set page(width: 21cm, height: auto, margin: 1cm)
#set text(font: "Libertinus Serif", size: 9pt)

#let cw = 8.9cm
#let row(title, png, fig) = {
  text(weight: "bold")[#title]
  v(2pt)
  grid(
    columns: (cw, cw), column-gutter: 0.8cm, align: top,
    box(width: cw, stroke: 0.4pt + luma(210), inset: 0pt, image(png, width: 100%)),
    box(width: cw, stroke: 0.4pt + luma(210), inset: 0pt, fig),
  )
  v(10pt)
}

#grid(columns: (cw, cw), column-gutter: 0.8cm,
  text(fill: gray)[Current (PNG from Python)], text(fill: gray)[Lilaq (vector, Typst)])
#v(4pt)

#row([Fig. 5: exact match by category], "../bench_by_category.png", fig-category())
#row([Fig. 6: grounding of the direct-LLM baseline], "../bench_baseline.png", fig-baseline())
#row([Fig. 7: rank agreement of weighting schemes], "../weight_tau_bar.png", fig-tau())
#row([Fig. 8: one-at-a-time weight sensitivity], "../weight_oat_sensitivity.png", fig-oat())
