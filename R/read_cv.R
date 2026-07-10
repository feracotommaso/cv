required_cv_sheets <- c(
  "profile", "entries", "teaching", "metrics", "publications",
  "labels", "versions", "settings", "declarations", "review"
)

optional_cv_sheets <- c("publication_authors")

as_cv_logical <- function(x) {
  if (is.logical(x)) return(replace(x, is.na(x), FALSE))
  y <- tolower(trimws(as.character(x)))
  y %in% c("true", "t", "1", "yes", "y", "si", "sì")
}

read_cv_workbook <- function(path = "data/cv.xlsx") {
  if (!file.exists(path)) {
    stop("CV workbook not found: ", normalizePath(path, mustWork = FALSE))
  }
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("Package 'readxl' is required. Run: Rscript install_packages.R")
  }

  available <- readxl::excel_sheets(path)
  missing <- setdiff(required_cv_sheets, available)
  if (length(missing)) {
    stop("Missing workbook sheets: ", paste(missing, collapse = ", "))
  }

  sheets_to_read <- c(required_cv_sheets, intersect(optional_cv_sheets, available))
  cv <- setNames(lapply(sheets_to_read, function(sheet) {
    readxl::read_excel(path, sheet = sheet, .name_repair = "unique")
  }), sheets_to_read)

  if (!"publication_authors" %in% names(cv)) {
    cv$publication_authors <- data.frame(
      publication_id = character(), author_order = numeric(),
      author_name = character(), is_self = logical(), show = logical(),
      stringsAsFactors = FALSE
    )
  }

  logical_columns <- c(
    "show", "include", "resolved", "corresponding", "international",
    "first_last", "preregistered", "open_data", "open_materials",
    "open_code", "is_self"
  )
  for (sheet in names(cv)) {
    for (column in intersect(names(cv[[sheet]]), logical_columns)) {
      cv[[sheet]][[column]] <- as_cv_logical(cv[[sheet]][[column]])
    }
  }

  cv$settings_map <- setNames(as.character(cv$settings$value), cv$settings$key)
  cv
}

required_columns <- list(
  profile = c("field", "label_en", "label_it", "value_en", "value_it", "show"),
  entries = c("entry_id", "section", "order", "date_en", "date_it", "text_en", "text_it", "show"),
  teaching = c("teaching_id", "type", "order", "course_en", "course_it", "show"),
  metrics = c("metric_id", "order", "indicator_en", "indicator_it", "scholar", "scopus", "wos", "show"),
  publications = c("publication_id", "order", "citation_en", "citation_it", "show"),
  labels = c("key", "en", "it"),
  versions = c("version", "section", "order", "include")
)

validate_cv_data <- function(cv, lang, selected_sections) {
  errors <- character()

  for (sheet in names(required_columns)) {
    absent <- setdiff(required_columns[[sheet]], names(cv[[sheet]]))
    if (length(absent)) {
      errors <- c(errors, sprintf("Sheet '%s' is missing columns: %s", sheet, paste(absent, collapse = ", ")))
    }
  }

  id_spec <- c(profile = "field", entries = "entry_id", teaching = "teaching_id",
               metrics = "metric_id", publications = "publication_id")
  for (sheet in names(id_spec)) {
    column <- id_spec[[sheet]]
    values <- cv[[sheet]][[column]]
    duplicated_values <- unique(values[duplicated(values) & !is.na(values)])
    if (length(duplicated_values)) {
      errors <- c(errors, sprintf("Duplicate IDs in '%s': %s", sheet, paste(duplicated_values, collapse = ", ")))
    }
  }

  known_sections <- names(section_function_registry())
  unknown <- setdiff(selected_sections, known_sections)
  if (length(unknown)) {
    errors <- c(errors, paste0("Unknown section names: ", paste(unknown, collapse = ", ")))
  }

  if (!lang %in% c("en", "it")) {
    errors <- c(errors, "Language must be 'en' or 'it'.")
  }

  if (length(errors)) stop(paste(errors, collapse = "\n"), call. = FALSE)
  invisible(TRUE)
}
