# Version 9: append-only IDs and order values

This patch is based on the exact workbook contained in the uploaded repository.
It preserves the user's current data and changes only the maintenance convention.

## Apply the patch

Extract the archive over the repository root and allow these files to be replaced:

- `data/cv.xlsx`
- `R/helpers.R`
- `R/sections.R`
- `R/publications.R`
- `README.md`

Then render normally:

```bash
Rscript render_cv.R en full "html,pdf"
```

## New convention

- Existing IDs are permanent and were not changed.
- A new ID uses the next unused suffix, such as `pub_051`.
- In `entries`, `teaching`, and `publications`, order values are append-only.
- For a new row, enter `max(order) + 1` in the relevant section/type/category.
- Larger order values are rendered first.
- Existing CV display order is preserved.
- Subsection order is preserved while a newly appended item appears first inside its subsection.

The semantic order columns in `versions`, `metrics`, and `declarations` remain ascending and were not changed.
