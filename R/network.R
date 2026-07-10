normalize_author_key <- function(x) {
  x <- iconv(as.character(x), to = "ASCII//TRANSLIT")
  tolower(gsub("[^[:alnum:]]", "", x))
}

authors_from_publications <- function(cv) {
  if (!"authors_network" %in% names(cv$publications)) return(data.frame())
  pubs <- shown_rows(cv$publications)
  pubs <- pubs[nonempty(pubs$publication_id) & nonempty(pubs$authors_network), , drop = FALSE]
  if (!nrow(pubs)) return(data.frame())

  self_name <- cv_setting(cv, "self_name_pattern", "Feraco, T.")
  self_key <- normalize_author_key(self_name)
  rows <- list()
  k <- 0L

  for (i in seq_len(nrow(pubs))) {
    author_names <- trimws(unlist(strsplit(as.character(pubs$authors_network[i]), ";", fixed = TRUE)))
    author_names <- author_names[nzchar(author_names)]
    if (!length(author_names)) next
    for (j in seq_along(author_names)) {
      k <- k + 1L
      rows[[k]] <- data.frame(
        publication_id = as.character(pubs$publication_id[i]),
        author_order = j,
        author_name = author_names[j],
        is_self = identical(normalize_author_key(author_names[j]), self_key),
        show = TRUE,
        stringsAsFactors = FALSE
      )
    }
  }

  if (!length(rows)) data.frame() else do.call(rbind, rows)
}

network_author_data <- function(cv) {
  primary <- authors_from_publications(cv)
  legacy <- cv$publication_authors

  if (!is.null(legacy) && nrow(legacy)) {
    legacy <- shown_rows(legacy)
    legacy <- legacy[nonempty(legacy$publication_id) & nonempty(legacy$author_name), , drop = FALSE]
    if (nrow(primary)) {
      legacy <- legacy[!legacy$publication_id %in% unique(primary$publication_id), , drop = FALSE]
    }
  }

  if (!nrow(primary) && (is.null(legacy) || !nrow(legacy))) return(data.frame())
  if (!nrow(primary)) return(legacy)
  if (is.null(legacy) || !nrow(legacy)) return(primary)
  rbind(primary, legacy[, intersect(names(primary), names(legacy)), drop = FALSE])
}

build_collaboration_graph <- function(cv) {
  if (!requireNamespace("igraph", quietly = TRUE)) {
    stop("Package 'igraph' is required for the collaborator network. Run: Rscript install_packages.R")
  }

  authors <- network_author_data(cv)
  if (!nrow(authors)) return(NULL)

  include_coauthors <- as_cv_logical(cv_setting(cv, "network_include_coauthor_edges", "TRUE"))
  self_names <- unique(as.character(authors$author_name[authors$is_self]))
  edge_list <- list()
  edge_index <- 0L

  for (publication_id in unique(authors$publication_id)) {
    names_in_paper <- unique(as.character(authors$author_name[authors$publication_id == publication_id]))
    if (length(names_in_paper) < 2) next
    pairs <- utils::combn(names_in_paper, 2)
    for (j in seq_len(ncol(pairs))) {
      pair <- sort(pairs[, j])
      if (!include_coauthors && !any(pair %in% self_names)) next
      edge_index <- edge_index + 1L
      edge_list[[edge_index]] <- data.frame(from = pair[1], to = pair[2], stringsAsFactors = FALSE)
    }
  }
  if (!length(edge_list)) return(NULL)

  edges <- do.call(rbind, edge_list)
  edges$weight <- 1
  edges <- stats::aggregate(weight ~ from + to, data = edges, FUN = sum)
  min_weight <- suppressWarnings(as.numeric(cv_setting(cv, "network_min_joint_papers", "1")))
  if (is.na(min_weight)) min_weight <- 1
  edges <- edges[edges$weight >= min_weight, , drop = FALSE]
  if (!nrow(edges)) return(NULL)

  vertices <- unique(authors[c("author_name", "is_self")])
  names(vertices) <- c("name", "is_self")
  pub_count <- stats::aggregate(publication_id ~ author_name, data = authors,
                                FUN = function(x) length(unique(x)))
  names(pub_count) <- c("name", "publications")
  vertices <- merge(vertices, pub_count, by = "name", all.x = TRUE)
  igraph::graph_from_data_frame(edges, directed = FALSE, vertices = vertices)
}

save_collaboration_network <- function(cv, path) {
  graph <- build_collaboration_graph(cv)
  if (is.null(graph) || igraph::vcount(graph) == 0) return(FALSE)

  seed <- suppressWarnings(as.integer(cv_setting(cv, "network_seed", "2026")))
  if (is.na(seed)) seed <- 2026L
  set.seed(seed)
  layout <- igraph::layout_with_fr(graph, weights = igraph::E(graph)$weight)

  max_labels <- suppressWarnings(as.integer(cv_setting(cv, "network_max_labels", "30")))
  if (is.na(max_labels) || max_labels < 1) max_labels <- 30L
  strength <- igraph::strength(graph, weights = igraph::E(graph)$weight)
  label_index <- order(strength, decreasing = TRUE)[seq_len(min(max_labels, length(strength)))]
  labels <- rep("", igraph::vcount(graph))
  labels[label_index] <- igraph::V(graph)$name[label_index]
  labels[igraph::V(graph)$is_self] <- igraph::V(graph)$name[igraph::V(graph)$is_self]

  sizes <- 5 + 2.4 * sqrt(pmax(1, igraph::V(graph)$publications))
  colors <- ifelse(igraph::V(graph)$is_self, "#17365D", "#B8CCE4")
  frame_colors <- ifelse(igraph::V(graph)$is_self, "#0B1F33", "#6B7C8F")
  label_colors <- ifelse(igraph::V(graph)$is_self, "#FFFFFF", "#1F1F1F")
  edge_width <- 0.5 + 1.15 * sqrt(igraph::E(graph)$weight)

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  grDevices::png(path, width = 2400, height = 1800, res = 220, bg = "white")
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(0, 0, 0, 0))
  plot(graph, layout = layout, vertex.size = sizes, vertex.color = colors,
       vertex.frame.color = frame_colors, vertex.label = labels,
       vertex.label.cex = 0.58, vertex.label.color = label_colors,
       edge.width = edge_width, edge.color = grDevices::adjustcolor("#6B7C8F", alpha.f = 0.42),
       edge.curved = 0.08, asp = 0)
  TRUE
}

section_collaborator_network <- function(cv, lang) {
  emit_heading(cv_label(cv, "collaborator_network", lang), if (is_html_cv()) 2 else 1)
  cat(cv_label(cv, "network_note", lang), "\n\n")
  path <- "assets/generated/collaborator-network.png"
  ok <- save_collaboration_network(cv, path)
  if (ok) {
    cat(sprintf("![](%s){width=96%% fig-alt=\"%s\"}\n\n", path, cv_label(cv, "collaborator_network", lang)))
  } else {
    cat(if (lang == "it") "Dati insufficienti per generare la rete.\n\n" else "Insufficient data to generate the network.\n\n")
  }
}
