# Fonts for the paper

The IEEE template used by `main.typ` (`charged-ieee`) asks for **TeX Gyre Termes** (body text)
and **TeX Gyre Cursor** (code). They are not installed by default, so Typst falls back to a
different font and the page layout shifts.

Compile with these fonts:

```
typst compile --font-path fonts main.typ main.pdf
```

(The Typst web app already includes them.)

## Source and licence

- TeX Gyre Termes 2.004: https://www.gust.org.pl/projects/e-foundry/tex-gyre/termes (`qtm2.004otf.zip`)
- TeX Gyre Cursor 2.004: https://www.gust.org.pl/projects/e-foundry/tex-gyre/cursor (`qcr2.004otf.zip`)

Both are by GUST, the Polish TeX Users Group, and are released under the GUST Font License
(an LPPL-style free licence that allows redistribution). The OpenType files are included here
unchanged.
