`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}

normalize_language <- function(lang) {
  lang <- tolower(trimws(as.character(lang %||% "en")))
  if (lang %in% c("english", "eng")) lang <- "en"
  if (lang %in% c("italian", "ita")) lang <- "it"
  if (!lang %in% c("en", "it")) stop("Unsupported language: ", lang)
  lang
}

nonempty <- function(x) {
  !is.na(x) & nzchar(trimws(as.character(x)))
}

knitr_pandoc_to <- function(format) {
  if (!requireNamespace("knitr", quietly = TRUE)) return(FALSE)
  fn <- get0("pandoc_to", envir = asNamespace("knitr"), mode = "function", inherits = FALSE)
  !is.null(fn) && isTRUE(fn(format))
}

is_html_cv <- function() {
  if (!requireNamespace("knitr", quietly = TRUE)) return(FALSE)
  isTRUE(knitr::is_html_output()) ||
    knitr_pandoc_to("html") ||
    grepl("html", as.character(knitr::opts_knit$get("rmarkdown.pandoc.to") %||% ""),
          ignore.case = TRUE)
}

is_latex_cv <- function() {
  if (!requireNamespace("knitr", quietly = TRUE)) return(FALSE)
  isTRUE(knitr::is_latex_output()) ||
    knitr_pandoc_to("latex") ||
    knitr_pandoc_to("beamer") ||
    grepl("latex|beamer", as.character(knitr::opts_knit$get("rmarkdown.pandoc.to") %||% ""),
          ignore.case = TRUE)
}

pick_language_value <- function(row, stem, lang, fallback = TRUE) {
  primary <- paste0(stem, "_", lang)
  secondary <- paste0(stem, "_", if (lang == "en") "it" else "en")
  value <- if (primary %in% names(row)) as.character(row[[primary]]) else ""
  if (fallback && !nonempty(value) && secondary %in% names(row)) {
    value <- as.character(row[[secondary]])
  }
  ifelse(is.na(value), "", value)
}

cv_label <- function(cv, key, lang = "en") {
  row <- cv$labels[cv$labels$key == key, , drop = FALSE]
  if (!nrow(row)) return(key)
  value <- as.character(row[[lang]][1])
  if (!nonempty(value)) value <- as.character(row[[if (lang == "en") "it" else "en"]][1])
  value
}

cv_setting <- function(cv, key, default = "") {
  value <- cv$settings_map[[key]]
  if (is.null(value) || is.na(value) || !nzchar(value)) default else value
}

shown_rows <- function(data) {
  if (!"show" %in% names(data)) return(data)
  data[!is.na(data$show) & data$show, , drop = FALSE]
}

sort_by_order <- function(data, decreasing = FALSE) {
  if (!"order" %in% names(data)) return(data)
  values <- suppressWarnings(as.numeric(data$order))
  if (isTRUE(decreasing)) values <- -values
  data[order(values, seq_len(nrow(data)), na.last = TRUE), , drop = FALSE]
}

record_group_key <- function(data, group_cols = NULL) {
  key <- rep("", nrow(data))
  for (column in intersect(group_cols %||% character(), names(data))) {
    value <- trimws(as.character(data[[column]]))
    use <- !nonempty(key) & nonempty(value)
    key[use] <- value[use]
  }
  key
}

# Chronological CV records use append-only order values: larger values are
# newer and are printed first. When a section contains subsections, the
# subsection sequence remains stable while records inside each subsection are
# sorted from the largest order value to the smallest.
sort_records_newest_first <- function(data, group_cols = NULL) {
  if (!nrow(data) || !"order" %in% names(data)) return(data)

  values <- suppressWarnings(as.numeric(data$order))
  if (!length(group_cols)) {
    return(data[order(-values, seq_len(nrow(data)), na.last = TRUE), , drop = FALSE])
  }

  key <- record_group_key(data, group_cols)
  anchor <- ave(
    values,
    key,
    FUN = function(x) if (all(is.na(x))) NA_real_ else min(x, na.rm = TRUE)
  )

  data[
    order(-anchor, -values, seq_len(nrow(data)), na.last = TRUE),
    ,
    drop = FALSE
  ]
}

markdown_link <- function(text, url) {
  if (!nonempty(url)) return(text)
  sprintf("[%s](%s)", text, url)
}

bold_self_name <- function(text, pattern = "Feraco, T.") {
  if (!nonempty(text)) return("")
  text <- gsub("(?<!\\*)(Feraco,?\\s*T\\.)(?!\\*)", "**\\1**", text, perl = TRUE)
  text <- gsub("(?<!\\*)(Feraco,?\\s*T)(?![A-Za-z.\\*])", "**\\1**", text, perl = TRUE)
  text
}

emit_heading <- function(text, level = 1) {
  cat(strrep("#", level), " ", text, "\n\n", sep = "")
}

emit_cv_header <- function(name, subtitle) {
  cat("::: {.cv-header}\n\n", sep = "")
  cat("::: {.cv-name}\n", name, "\n:::\n\n", sep = "")
  cat("::: {.cv-subtitle}\n", subtitle, "\n:::\n\n", sep = "")
  cat(":::\n\n")
}

emit_cv_entry <- function(date, body) {
  cat("::: {.cv-entry}\n\n")
  cat("::: {.cv-date}\n", date, "\n:::\n\n", sep = "")
  cat("::: {.cv-body}\n", body, "\n:::\n\n", sep = "")
  cat(":::\n\n")
}

render_definition_entries_html <- function(data, cv, lang, numbered_when_undated = FALSE) {
  data <- sort_records_newest_first(
    shown_rows(data),
    group_cols = c("subsection_en", "subsection_it")
  )
  if (!nrow(data)) return(invisible(NULL))

  subsection_col <- paste0("subsection_", lang)
  date_col <- paste0("date_", lang)
  text_col <- paste0("text_", lang)
  fallback_lang <- if (lang == "en") "it" else "en"
  fallback_subsection_col <- paste0("subsection_", fallback_lang)
  fallback_date_col <- paste0("date_", fallback_lang)
  fallback_text_col <- paste0("text_", fallback_lang)

  subsection <- if (subsection_col %in% names(data)) as.character(data[[subsection_col]]) else rep("", nrow(data))
  fallback_subsection <- if (fallback_subsection_col %in% names(data)) as.character(data[[fallback_subsection_col]]) else rep("", nrow(data))
  subsection[!nonempty(subsection)] <- fallback_subsection[!nonempty(subsection)]

  date <- if (date_col %in% names(data)) as.character(data[[date_col]]) else rep("", nrow(data))
  fallback_date <- if (fallback_date_col %in% names(data)) as.character(data[[fallback_date_col]]) else rep("", nrow(data))
  date[!nonempty(date)] <- fallback_date[!nonempty(date)]

  text <- if (text_col %in% names(data)) as.character(data[[text_col]]) else rep("", nrow(data))
  fallback_text <- if (fallback_text_col %in% names(data)) as.character(data[[fallback_text_col]]) else rep("", nrow(data))
  text[!nonempty(text)] <- fallback_text[!nonempty(text)]

  current_subsection <- NULL
  use_numbered <- numbered_when_undated && !any(nonempty(date))
  list_open <- FALSE

  close_list <- function() {
    if (list_open && !use_numbered) cat(":::\n\n")
  }

  for (i in seq_len(nrow(data))) {
    sub <- ifelse(is.na(subsection[i]), "", trimws(subsection[i]))
    if (!identical(sub, current_subsection)) {
      close_list()
      list_open <- FALSE
      current_subsection <- sub
      if (nonempty(sub)) emit_heading(sub, 3)
    }

    item <- text[i]
    if ("url" %in% names(data) && nonempty(data$url[i])) {
      item <- paste0(item, " [Link](", data$url[i], ")")
    }

    if (use_numbered) {
      cat("1. ", item, "\n\n", sep = "")
    } else if (!nonempty(date[i])) {
      close_list()
      list_open <- FALSE
      cat("- ", item, "\n\n", sep = "")
    } else {
      if (!list_open) {
        cat("::: {.cv-list}\n\n")
        list_open <- TRUE
      }
      cat(date[i], "\n:   ", item, "\n\n", sep = "")
    }
  }
  close_list()
  invisible(NULL)
}

render_definition_entries_pdf <- function(data, cv, lang, numbered_when_undated = FALSE) {
  data <- sort_records_newest_first(
    shown_rows(data),
    group_cols = c("subsection_en", "subsection_it")
  )
  if (!nrow(data)) return(invisible(NULL))

  subsection_col <- paste0("subsection_", lang)
  date_col <- paste0("date_", lang)
  text_col <- paste0("text_", lang)
  fallback_lang <- if (lang == "en") "it" else "en"
  fallback_subsection_col <- paste0("subsection_", fallback_lang)
  fallback_date_col <- paste0("date_", fallback_lang)
  fallback_text_col <- paste0("text_", fallback_lang)

  subsection <- if (subsection_col %in% names(data)) as.character(data[[subsection_col]]) else rep("", nrow(data))
  fallback_subsection <- if (fallback_subsection_col %in% names(data)) as.character(data[[fallback_subsection_col]]) else rep("", nrow(data))
  subsection[!nonempty(subsection)] <- fallback_subsection[!nonempty(subsection)]

  date <- if (date_col %in% names(data)) as.character(data[[date_col]]) else rep("", nrow(data))
  fallback_date <- if (fallback_date_col %in% names(data)) as.character(data[[fallback_date_col]]) else rep("", nrow(data))
  date[!nonempty(date)] <- fallback_date[!nonempty(date)]

  text <- if (text_col %in% names(data)) as.character(data[[text_col]]) else rep("", nrow(data))
  fallback_text <- if (fallback_text_col %in% names(data)) as.character(data[[fallback_text_col]]) else rep("", nrow(data))
  text[!nonempty(text)] <- fallback_text[!nonempty(text)]

  current_subsection <- NULL
  use_numbered <- numbered_when_undated && !any(nonempty(date))

  for (i in seq_len(nrow(data))) {
    sub <- ifelse(is.na(subsection[i]), "", trimws(subsection[i]))
    if (!identical(sub, current_subsection)) {
      current_subsection <- sub
      if (nonempty(sub)) emit_heading(sub, 2)
    }

    item <- text[i]
    if ("url" %in% names(data) && nonempty(data$url[i])) {
      item <- paste0(item, " [Link](", data$url[i], ")")
    }

    if (use_numbered) {
      cat("1. ", item, "\n\n", sep = "")
    } else if (!nonempty(date[i])) {
      cat("- ", item, "\n\n", sep = "")
    } else {
      emit_cv_entry(date[i], item)
    }
  }
  invisible(NULL)
}

render_definition_entries <- function(data, cv, lang, numbered_when_undated = FALSE) {
  if (is_html_cv()) {
    render_definition_entries_html(data, cv, lang, numbered_when_undated)
  } else {
    render_definition_entries_pdf(data, cv, lang, numbered_when_undated)
  }
}

render_kable <- function(data, align = NULL, longtable = FALSE) {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    stop("Package 'knitr' is required. Run: Rscript install_packages.R")
  }
  if (is_html_cv()) {
    cat(knitr::kable(data, format = "html", escape = TRUE, align = align,
                     table.attr = 'class="cv-table"'), sep = "\n")
  } else {
    cat("\\begingroup\\small\n")
    cat(knitr::kable(data, format = "latex", escape = TRUE, align = align,
                     booktabs = TRUE, longtable = longtable), sep = "\n")
    cat("\\endgroup\n")
  }
  cat("\n\n")
}

render_teaching_table <- function(data) {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    stop("Package 'knitr' is required. Run: Rscript install_packages.R")
  }

  if (is_html_cv()) {
    render_kable(data, align = c("l", "c", "l", "c", "c"), longtable = TRUE)
    return(invisible(NULL))
  }

  latex <- knitr::kable(
    data,
    format = "latex",
    escape = TRUE,
    align = c("l", "c", "l", "c", "c"),
    booktabs = TRUE,
    longtable = TRUE
  )
  lines <- strsplit(paste(latex, collapse = "\n"), "\n", fixed = TRUE)[[1]]
  begin_index <- grep("^\\\\begin\\{longtable\\}", lines)
  if (!length(begin_index)) stop("Could not identify the teaching longtable output.")

  column_spec <- paste0(
    "@{}",
    ">{\\RaggedRight\\arraybackslash}p{4.00cm}",
    ">{\\centering\\arraybackslash}p{0.90cm}",
    ">{\\RaggedRight\\arraybackslash}p{7.20cm}",
    ">{\\centering\\arraybackslash}p{1.80cm}",
    ">{\\centering\\arraybackslash}p{1.70cm}",
    "@{}"
  )
  lines[begin_index[1]] <- paste0("\\begin{longtable}[t]{", column_spec, "}")

  cat("\\begingroup\n")
  cat("\\scriptsize\n")
  cat("\\setlength{\\tabcolsep}{3pt}\n")
  cat("\\renewcommand{\\arraystretch}{1.06}\n")
  cat("\\setlength{\\LTleft}{0pt}\n")
  cat("\\setlength{\\LTright}{0pt}\n")
  cat(paste(lines, collapse = "\n"), "\n", sep = "")
  cat("\\endgroup\n\n")
  invisible(NULL)
}

format_cv_date <- function(date = Sys.Date(), lang = "en") {
  day <- as.integer(format(date, "%d"))
  month_number <- as.integer(format(date, "%m"))
  year <- format(date, "%Y")
  month_en <- c("January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December")
  month_it <- c("gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
                "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre")
  if (lang == "it") {
    sprintf("%d %s %s", day, month_it[month_number], year)
  } else {
    sprintf("%d %s %s", day, month_en[month_number], year)
  }
}
