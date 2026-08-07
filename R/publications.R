badge_specs <- function() {
  list(
    preregistered = c("assets/badges/preregistered.png", "preregistration_url"),
    open_data = c("assets/badges/open-data.png", "data_url"),
    open_materials = c("assets/badges/open-materials.png", "materials_url"),
    open_code = c("assets/badges/open-code.png", "code_url")
  )
}

html_escape <- function(x) {
  x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

latex_escape_url <- function(x) {
  gsub("[{}]", "", as.character(x))
}

base64_encode_raw <- function(bytes) {
  alphabet_text <- "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  alphabet <- substring(alphabet_text, seq_len(nchar(alphabet_text)), seq_len(nchar(alphabet_text)))
  values <- as.integer(bytes)
  if (!length(values)) return("")
  output <- character(ceiling(length(values) / 3) * 4)
  out_index <- 1L

  for (start in seq.int(1L, length(values), by = 3L)) {
    chunk <- values[start:min(start + 2L, length(values))]
    b1 <- chunk[1]
    b2 <- if (length(chunk) >= 2L) chunk[2] else 0L
    b3 <- if (length(chunk) >= 3L) chunk[3] else 0L
    number <- bitwShiftL(b1, 16L) + bitwShiftL(b2, 8L) + b3
    indices <- c(
      bitwAnd(bitwShiftR(number, 18L), 63L),
      bitwAnd(bitwShiftR(number, 12L), 63L),
      bitwAnd(bitwShiftR(number, 6L), 63L),
      bitwAnd(number, 63L)
    ) + 1L

    output[out_index] <- alphabet[indices[1]]
    output[out_index + 1L] <- alphabet[indices[2]]
    output[out_index + 2L] <- if (length(chunk) >= 2L) alphabet[indices[3]] else "="
    output[out_index + 3L] <- if (length(chunk) >= 3L) alphabet[indices[4]] else "="
    out_index <- out_index + 4L
  }
  paste0(output, collapse = "")
}

image_data_uri <- function(path) {
  extension <- tolower(tools::file_ext(path))
  mime <- switch(extension,
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    gif = "image/gif",
    svg = "image/svg+xml",
    "application/octet-stream"
  )
  size <- file.info(path)$size
  bytes <- readBin(path, what = "raw", n = size)
  paste0("data:", mime, ";base64,", base64_encode_raw(bytes))
}

badge_markup <- function(asset, url = "", alt = "Open science badge") {
  if (!file.exists(asset)) stop("Badge image not found: ", asset)

  if (is_latex_cv()) {
    image <- sprintf("\\includegraphics[height=1.2em]{%s}", asset)
    if (nonempty(url)) {
      return(sprintf("\\href{\\detokenize{%s}}{%s}", latex_escape_url(url), image))
    }
    return(image)
  }

  if (is_html_cv()) {
    source <- image_data_uri(asset)
    image <- sprintf(
      '<img class="os-badge" src="%s" alt="%s"/>',
      source, html_escape(alt)
    )
    if (nonempty(url)) {
      return(sprintf('<a class="badge-link" href="%s" title="%s">%s</a>',
                     html_escape(url), html_escape(alt), image))
    }
    return(image)
  }

  image <- sprintf("![%s](%s){width=0.22in}", alt, asset)
  if (nonempty(url)) sprintf("[%s](%s)", image, url) else image
}

publication_symbol_set <- function() {
  if (is_html_cv()) {
    return(list(first_last = "⅟", corresponding = "✉", international = "✝"))
  }
  list(first_last = "1/L", corresponding = "C", international = "INT")
}

publication_prefix <- function(row) {
  symbols <- publication_symbol_set()
  out <- character()
  if (isTRUE(row$first_last)) out <- c(out, symbols$first_last)
  if (isTRUE(row$corresponding)) out <- c(out, symbols$corresponding)
  if (isTRUE(row$international)) out <- c(out, symbols$international)
  paste(out, collapse = if (is_html_cv()) "" else " ")
}

publication_badges <- function(row, cv, lang) {
  specs <- badge_specs()
  out <- character()
  for (flag in names(specs)) {
    if (isTRUE(row[[flag]])) {
      url_column <- specs[[flag]][2]
      url <- if (url_column %in% names(row)) row[[url_column]] else ""
      out <- c(out, badge_markup(specs[[flag]][1], url, cv_label(cv, flag, lang)))
    }
  }
  paste(out, collapse = if (is_html_cv()) " " else "\\hspace{0.08em}")
}

render_badge_legend <- function(cv, lang) {
  symbols <- publication_symbol_set()

  # Keep the legend in a fenced Div for both formats. This is more reliable
  # than emitting raw HTML directly inside a Markdown list or paragraph.
  cat("::: {.cv-pub-legend}\n\n")
  cat("**", symbols$first_last, "** = ", cv_label(cv, "first_last_author", lang), "; ", sep = "")
  cat("**", symbols$corresponding, "** = ", cv_label(cv, "corresponding_author", lang), "; ", sep = "")
  cat("**", symbols$international, "** = ", cv_label(cv, "international_authors", lang), "  \n", sep = "")

  legend_parts <- character()
  for (flag in names(badge_specs())) {
    asset <- badge_specs()[[flag]][1]
    legend_parts <- c(
      legend_parts,
      paste0(badge_markup(asset, "", cv_label(cv, flag, lang)), " = ", cv_label(cv, flag, lang))
    )
  }
  cat(paste(legend_parts, collapse = if (is_html_cv()) " &nbsp;&nbsp; " else "; "), "\n\n", sep = "")
  cat(":::\n\n")
}

emit_publication <- function(number, text, badges = "") {
  cat("::: {.cv-publication}\n\n")
  cat("::: {.cv-pub-number}\n", number, "\n:::\n\n", sep = "")
  cat("::: {.cv-pub-text}\n", text, "\n:::\n\n", sep = "")
  cat("::: {.cv-pub-badges}\n", badges, "\n:::\n\n", sep = "")
  cat(":::\n\n")
}

emit_publication_html <- function(number, text, badges = "") {
  # The outer Div uses a four-colon fence because it contains nested
  # three-colon Divs. Every class must also have its own leading dot.
  # Without the second dot, Pandoc treats the fence as literal text.
  cat(":::: {.cv-publication .cv-publication-html}\n\n")
  cat("::: {.cv-pub-number}\n", number, "\n:::\n\n", sep = "")
  cat("::: {.cv-pub-text}\n", text, sep = "")
  if (nonempty(badges)) {
    # Raw badge HTML is deliberately emitted inside a normal Div rather than
    # appended to a Markdown list item. This preserves the old compact visual
    # style while avoiding the disappearing-image behaviour seen in Quarto.
    cat(' <span class="cv-inline-badges">', badges, "</span>", sep = "")
  }
  cat("\n:::\n\n")
  cat("::::\n\n")
}

publication_index_count <- function(cv, database = c("scopus", "wos")) {
  database <- match.arg(database)
  
  data <- shown_rows(cv$publications)
  
  if (!"metrics_text" %in% names(data)) {
    warning(
      "The publications sheet does not contain a 'metrics_text' column.",
      call. = FALSE
    )
    return(NA_integer_)
  }
  
  metrics_text <- as.character(data$metrics_text)
  metrics_text[is.na(metrics_text)] <- ""
  
  pattern <- switch(
    database,
    scopus = "\\bScopus\\b",
    wos = "\\bJCR\\b"
  )
  
  sum(
    grepl(
      pattern,
      metrics_text,
      ignore.case = TRUE,
      perl = TRUE
    )
  )
}

render_publication_summary <- function(cv, lang) {
  data <- shown_rows(cv$publications)
  
  total <- nrow(data)
  
  first_last <- if ("first_last" %in% names(data)) {
    sum(data$first_last, na.rm = TRUE)
  } else {
    0L
  }
  
  scopus <- publication_index_count(cv, "scopus")
  wos <- publication_index_count(cv, "wos")
  
  if (is.na(scopus) || is.na(wos)) {
    warning(
      paste(
        "The publication summary could not calculate the",
        "Scopus or Web of Science publication totals",
        "from the publications sheet."
      ),
      call. = FALSE
    )
  }
  
  if (lang == "it") {
    sentence <- sprintf(
      paste0(
        "Ho pubblicato **%s** articoli in riviste peer-reviewed, ",
        "**%s** come primo/ultimo autore; **%s** sono indicizzati ",
        "in Web of Science e **%s** in Scopus."
      ),
      total,
      first_last,
      wos,
      scopus
    )
  } else {
    sentence <- sprintf(
      paste0(
        "I have published **%s** articles in peer-reviewed journals, ",
        "**%s** as first/last author; **%s** are indexed in ",
        "Web of Science and **%s** in Scopus."
      ),
      total,
      first_last,
      wos,
      scopus
    )
  }
  
  cat(sentence, "\n\n")
}

section_publications <- function(cv, lang) {
  emit_heading(cv_label(cv, "publications", lang), if (is_html_cv()) 2 else 1)
  emit_heading(cv_label(cv, "peer_reviewed", lang), if (is_html_cv()) 3 else 2)
  if (isTRUE(cv$render_options$publication_summary)) {
    render_publication_summary(cv, lang)
  }
  render_badge_legend(cv, lang)

  data <- sort_records_newest_first(shown_rows(cv$publications))
  self_pattern <- cv_setting(cv, "self_name_pattern", "Feraco, T.")
  citation_col <- paste0("citation_", lang)
  fallback_col <- paste0("citation_", if (lang == "en") "it" else "en")

  for (i in seq_len(nrow(data))) {
    row <- data[i, , drop = FALSE]
    citation <- as.character(row[[citation_col]])
    if (!nonempty(citation)) citation <- as.character(row[[fallback_col]])
    citation <- bold_self_name(citation, self_pattern)
    prefix <- publication_prefix(row)
    metrics <- if (nonempty(row$metrics_text)) paste0(" *", row$metrics_text, "*") else ""
    badges <- publication_badges(row, cv, lang)

    if (is_html_cv()) {
      prefix_text <- if (nonempty(prefix)) paste0("**", prefix, "** ") else ""
      emit_publication_html(i, paste0(prefix_text, citation, metrics), badges)
    } else {
      prefix_text <- if (nonempty(prefix)) paste0("[", prefix, "]{.pub-flags} ") else ""
      emit_publication(i, paste0(prefix_text, citation, metrics), badges)
    }
  }
}
