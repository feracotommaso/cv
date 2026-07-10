# Version 8 patch

This patch adds an optional bilingual publication-summary sentence without changing `data/cv.xlsx`.

Copy the patch contents over the existing Version 7 project and allow these files to be replaced:

- `R/publications.R`
- `cv.qmd`
- `render_cv.R`

The summary is included by default:

```bash
Rscript render_cv.R en full
```

Exclude it without editing Excel:

```bash
Rscript render_cv.R en full --publication-summary=no
```

Include it explicitly:

```bash
Rscript render_cv.R it full --publication-summary=yes
```

It can be combined with formats and custom sections:

```bash
Rscript render_cv.R en full pdf "profile,current_position,metrics,publications,signature" --publication-summary=no
```

The total article and first/last-author counts are calculated from the `publications` sheet. The WOS and Scopus counts are read from the existing `Publications` row in the `metrics` sheet.
