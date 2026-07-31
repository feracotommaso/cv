# Academic CV with Quarto + Excel

This project generates my academic Curriculum Vitae from a single Excel workbook.

The workbook is the **only file that should normally be edited**. All CV versions (Italian, English, HTML, PDF, etc.) are automatically generated from it.

---

# Project structure

```
.
├── assets/
│   ├── badges/
│   ├── generated/
│   └── signature.png [git-ignored]
│
├── data/
│   └── cv.xlsx
│
├── R/
│   ├── helpers.R
│   ├── publications.R
│   ├── read_cv.R
│   ├── sections.R
│   └── network.R
│
├── styles/
│   ├── cv.css
│   └── cv-pdf.tex
│
├── filters/
│   └── cv-layout.lua
│
├── docs/
│
├── cv.qmd
├── render_cv.R
├── install_packages.R
└── README.md
```

---

# Installation

Install **R**.

Install **Quarto**.

For PDF output install **TinyTeX** (or another XeLaTeX distribution).

Install the required R packages once:

```bash
Rscript install_packages.R
```

---

# Editing the CV

Only edit

```
data/cv.xlsx
```

The workbook contains one sheet for each CV section.

Examples:

- profile
- positions
- education
- teaching
- grants
- publications
- metrics
- versions

Normally there is **no need to modify any R script**.

## Adding new records: IDs and order

Record IDs are permanent identifiers. Do **not** renumber existing IDs when a new row is added. Use the next unused numeric suffix, for example:

```text
past_positions_007
pub_051
```

The ID does not determine where the record appears in the CV.

For the `entries`, `teaching`, and `publications` sheets, the `order` field is append-only:

- in `entries`, use `max(order) + 1` within the relevant `section`;
- in `teaching`, use `max(order) + 1` within the relevant `type`;
- in `publications`, use `max(order) + 1` within the relevant `category`.

Larger order values are printed first, so a newly added record appears before older records without changing previous rows. The renderer preserves the established order of subsections.

The `order` fields in `versions`, `metrics`, and `declarations` remain conventional ascending display positions and should not be treated as chronological append-only fields.

---

# Languages

The CV can be rendered in

- English (`en`)
- Italian (`it`)

---

# Rendering

Before rendering, add your `signature.png` file in the `assets/` folder

## Full English CV

```bash
Rscript render_cv.R en full
```

## Full Italian CV

```bash
Rscript render_cv.R it full
```

---

## HTML only

```bash
Rscript render_cv.R en full html
```

---

## PDF only

```bash
Rscript render_cv.R en full pdf
```

---

## HTML + PDF

```bash
Rscript render_cv.R en full "html,pdf"
```

---

# Available versions

Versions are defined inside the **versions** sheet.

Typical versions are

- full
- short
- research
- teaching

Each version simply specifies which sections should be printed.

---

# Rendering only selected sections

Instead of using the preset stored in Excel, sections can be specified manually.

Example

```bash
Rscript render_cv.R en full pdf "profile,current_position,education,metrics,publications,signature"
```

The list overrides the preset in Excel.

---

# Publication summary

The publications section can optionally start with an automatically generated summary.

Example

> I have published 49 peer-reviewed articles, 31 as first/last author; 48 are indexed in Web of Science and 48 in Scopus.

The numbers are computed automatically from

- Publications sheet
- Metrics sheet

To disable it

```bash
Rscript render_cv.R en full --publication-summary=no
```

To enable it explicitly

```bash
Rscript render_cv.R en full --publication-summary=yes
```

---

# Open Science badges

Each publication may contain four badges.

- preregistration
- open data
- open materials
- open code

The badges appear automatically whenever the corresponding field is enabled.

If a URL is supplied, the badge becomes clickable.

Badge images are stored in

```
assets/badges/
```

There is normally no need to modify them.

---

# Collaborator network

The collaborator network is generated automatically from the authors listed in the Publications sheet.

No separate author table is required.

The generated figure is stored in

```
assets/generated/
```

---

# Signature

The signature image is

```
assets/signature.png
```

Replace this file if a different signature is desired.

---

# Output

Rendered files are written to

```
docs/
```

Typical files are

```
docs/cv.html
docs/cv.pdf
```

---

# Publishing on GitHub Pages

Enable **GitHub Pages** using:

- **Branch:** `main`
- **Folder:** `/docs`

Render the CV

```bash
Rscript render_cv.R en full html
```

or

```bash
Rscript render_cv.R en full "html,pdf"
```

Commit and push:

```bash
git add docs
git commit -m "Update CV"
git push
```

The CV will then be available at

```
https://USERNAME.github.io/REPOSITORY/cv.html
```

or, if the HTML is rendered as `index.html`,

```
https://USERNAME.github.io/REPOSITORY/
```

---

# Updating the CV

The normal workflow is

1. Edit `data/cv.xlsx`

2. Render

```bash
Rscript render_cv.R en full "html,pdf"
```

3. Verify the output in `docs/`

4. Commit

```bash
git add .
git commit -m "Update CV"
git push
```

---

# Notes

- HTML and PDF have independent layouts.
- PDF uses XeLaTeX.
- HTML badges are embedded and do not depend on external image paths.
- The workbook is the single source of truth.
- The R scripts should normally never require editing.