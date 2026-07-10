resolve_sections <- function(cv, version = "full", override = "") {
  if (!is.null(override) && length(override) && nonempty(override)) {
    sections <- trimws(unlist(strsplit(as.character(override), ",", fixed = TRUE)))
    return(sections[nzchar(sections)])
  }

  rows <- cv$versions[cv$versions$version == version & cv$versions$include, , drop = FALSE]
  if (!nrow(rows)) stop("Unknown or empty CV version: ", version)
  rows <- rows[order(suppressWarnings(as.numeric(rows$order))), , drop = FALSE]
  as.character(rows$section)
}

section_heading_level <- function() {
  if (is_html_cv()) 2 else 1
}

subsection_heading_level <- function() {
  if (is_html_cv()) 3 else 2
}

section_entries <- function(cv, lang, section, numbered_when_undated = FALSE) {
  emit_heading(cv_label(cv, section, lang), section_heading_level())
  data <- cv$entries[cv$entries$section == section, , drop = FALSE]
  render_definition_entries(data, cv, lang, numbered_when_undated = numbered_when_undated)
}

section_profile <- function(cv, lang) {
  data <- shown_rows(cv$profile)
  labels <- if (lang == "en") data$label_en else data$label_it
  values <- if (lang == "en") data$value_en else data$value_it
  fallback <- if (lang == "en") data$value_it else data$value_en
  values[!nonempty(values)] <- fallback[!nonempty(values)]

  if (is_html_cv()) {
    cat("# Tommaso Feraco\n\n")
    cat("**", cv_label(cv, "cv_title", lang), "**\n\n", sep = "")
    emit_heading(cv_label(cv, "profile", lang), 2)
    for (i in seq_len(nrow(data))) {
      value <- values[i]
      if (nonempty(data$url[i])) value <- markdown_link(value, data$url[i])
      cat("**", labels[i], ":** ", value, "  \n", sep = "")
    }
    cat("\n")
    return(invisible(NULL))
  }

  emit_cv_header("Tommaso Feraco", cv_label(cv, "cv_title", lang))
  emit_heading(cv_label(cv, "profile", lang), 1)
  for (i in seq_len(nrow(data))) {
    value <- values[i]
    if (nonempty(data$url[i])) value <- markdown_link(value, data$url[i])
    emit_cv_entry(paste0("**", labels[i], "**"), value)
  }
}

section_current_position <- function(cv, lang) section_entries(cv, lang, "current_position")
section_past_positions <- function(cv, lang) section_entries(cv, lang, "past_positions")
section_education <- function(cv, lang) section_entries(cv, lang, "education")
section_training <- function(cv, lang) section_entries(cv, lang, "training")
section_abroad <- function(cv, lang) section_entries(cv, lang, "abroad")
section_public_engagement <- function(cv, lang) section_entries(cv, lang, "public_engagement")
section_awards_grants <- function(cv, lang) section_entries(cv, lang, "awards_grants")
section_collaborations <- function(cv, lang) section_entries(cv, lang, "collaborations")
section_research_groups <- function(cv, lang) section_entries(cv, lang, "research_groups")
section_conference_organization <- function(cv, lang) section_entries(cv, lang, "conference_organization")
section_memberships <- function(cv, lang) section_entries(cv, lang, "memberships")
section_institutional_positions <- function(cv, lang) section_entries(cv, lang, "institutional_positions")
section_editorial <- function(cv, lang) section_entries(cv, lang, "editorial")
section_competences <- function(cv, lang) section_entries(cv, lang, "competences")
section_other_publications <- function(cv, lang) section_entries(cv, lang, "other_publications", TRUE)
section_presentations <- function(cv, lang) section_entries(cv, lang, "presentations", TRUE)

section_recommendation_letters <- function(cv, lang) {
  data <- cv$entries[cv$entries$section == "recommendation_letters", , drop = FALSE]
  text_col <- paste0("text_", lang)
  if (!text_col %in% names(data) || !any(nonempty(data[[text_col]]))) return(invisible(NULL))
  emit_heading(cv_label(cv, "recommendation_letters", lang), section_heading_level())
  render_definition_entries(data, cv, lang, numbered_when_undated = TRUE)
}

section_teaching <- function(cv, lang) {
  emit_heading(cv_label(cv, "teaching", lang), section_heading_level())
  data <- sort_by_order(shown_rows(cv$teaching))
  for (type in c("main", "assistant")) {
    subset <- data[data$type == type, , drop = FALSE]
    if (!nrow(subset)) next
    emit_heading(cv_label(cv, paste0("teaching_", type), lang), subsection_heading_level())
    clean_table_text <- function(x) gsub("\\*", "", as.character(x))
    table <- data.frame(
      Course = clean_table_text(if (lang == "en") subset$course_en else subset$course_it),
      Level = clean_table_text(subset$level),
      Degree = clean_table_text(if (lang == "en") subset$degree_en else subset$degree_it),
      Year = clean_table_text(subset$year),
      `Hours / CFU` = clean_table_text(subset$hours_cfu),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
    if (lang == "it") names(table) <- c("Corso", "Livello", "Corso di laurea", "AA", "Ore / CFU")
    render_teaching_table(table)
  }

  extra <- cv$entries[cv$entries$section == "teaching_extra", , drop = FALSE]
  render_definition_entries(extra, cv, lang)
}

section_metrics <- function(cv, lang) {
  emit_heading(cv_label(cv, "metrics", lang), section_heading_level())
  updated <- cv_setting(cv, "metrics_updated", "")
  if (nonempty(updated)) {
    cat("*", cv_label(cv, "updated", lang), ": ", updated, "*\n\n", sep = "")
  }
  data <- sort_by_order(shown_rows(cv$metrics))
  table <- data.frame(
    Indicator = if (lang == "en") data$indicator_en else data$indicator_it,
    Scholar = data$scholar,
    Scopus = data$scopus,
    WOS = data$wos,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  if (lang == "it") names(table)[1] <- "Indicatore"
  render_kable(table, align = c("l", "c", "c", "c"), longtable = FALSE)
  cat("*", cv_label(cv, "metrics_note", lang), "*\n\n", sep = "")
}

section_declarations <- function(cv, lang) {
  emit_heading(cv_label(cv, "declarations", lang), section_heading_level())
  data <- sort_by_order(shown_rows(cv$declarations))
  text_col <- paste0("text_", lang)
  for (i in seq_len(nrow(data))) cat(data[[text_col]][i], "\n\n")
}

section_signature <- function(cv, lang) {
  cat("\n\nPadova, ", format_cv_date(Sys.Date(), lang), "\n\n", sep = "")
  signature <- cv_setting(cv, "signature_file", "")
  if (nonempty(signature) && file.exists(signature)) {
    cat("![](", signature, "){width=1.75in}\n\n", sep = "")
  }
  cat("Tommaso Feraco\n\n")
}

section_function_registry <- function() {
  list(
    profile = section_profile,
    current_position = section_current_position,
    past_positions = section_past_positions,
    education = section_education,
    training = section_training,
    teaching = section_teaching,
    abroad = section_abroad,
    public_engagement = section_public_engagement,
    awards_grants = section_awards_grants,
    collaborations = section_collaborations,
    research_groups = section_research_groups,
    conference_organization = section_conference_organization,
    memberships = section_memberships,
    institutional_positions = section_institutional_positions,
    editorial = section_editorial,
    competences = section_competences,
    metrics = section_metrics,
    publications = section_publications,
    other_publications = section_other_publications,
    presentations = section_presentations,
    collaborator_network = section_collaborator_network,
    recommendation_letters = section_recommendation_letters,
    declarations = section_declarations,
    signature = section_signature
  )
}

render_cv_sections <- function(cv, lang, sections) {
  registry <- section_function_registry()
  for (section in sections) {
    registry[[section]](cv, lang)
  }
  invisible(NULL)
}
