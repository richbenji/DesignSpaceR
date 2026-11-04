# app.R
library(shiny)
library(shinydashboard)
library(DT)
library(plotly)
library(ggplot2)
library(dplyr)
library(rlang) # pour le pronoun .data
library(colourpicker)

ui <- dashboardPage(
  dashboardHeader(title = "DesignSpaceR"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Tutorial", tabName = "tutorial", icon = icon("book")),
      menuItem("Parameters range", tabName = "param_simu", icon = icon("sliders-h")),
      menuItem("Randomization of parameters", tabName = "result_simu", icon = icon("cogs")),
      menuItem("Global design space", tabName = "exploration", icon = icon("chart-area")),
      menuItem("Design space", tabName = "prediction", icon = icon("chart-line"))
    )
  ),
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .btn-sm { padding: 6px 8px; }
        .param-row { margin-bottom: 8px; padding-bottom:4px; border-bottom: 1px solid #eee; }
        .small-label { font-size: 90%; color: #555; }
        .cqa-row { margin-bottom: 10px; padding: 10px; border: 1px solid #e9e9e9; border-radius: 6px; }
        .cqa-scroll { max-height: 380px; overflow-y: auto; padding-right: 8px; }
      "))
    ),
    tabItems(
      # -------------------- TUTORIAL --------------------
      tabItem(tabName = "tutorial",
              fluidRow(
                box(width = 12, title = "DesignSpaceR Tutorial", status = "primary", solidHeader = TRUE,
                    includeMarkdown("README.md"))
              )
      ),
      # -------------------- SIMULATION PARAMETERS --------------------
      tabItem(tabName = "param_simu",
              fluidRow(
                box(width = 12, title = "Parameter configuration", status = "primary", solidHeader = TRUE,
                    p("Define your parameters. By default each parameter uses a fixed concentration value. Tick 'Use range' to define a min / max range."),
                    uiOutput("param_table_ui"),
                    br(),
                    actionButton("add_param", "➕ Add parameter"),
                    br(), br()
                )
              )
      ),
      # -------------------- RANDOMIZATION (SIMULATION RESULTS) --------------------
      tabItem(tabName = "result_simu",
              fluidRow(
                box(width = 4, title = "Simulation controls", status = "warning", solidHeader = TRUE,
                    numericInput("n_simu", "Number of simulations", value = 2500, min = 1, step = 1),
                    numericInput("seed", "Seed", value = 123, step = 1),
                    br(), br(),
                    actionButton("run_simu", "Run simulation")
                ),
                box(width = 8, title = "Simulation outputs", status = "success", solidHeader = TRUE,
                    DTOutput("table_simu"),
                    br(),
                    downloadButton("download_simu", "Download simulations (CSV)")
                )
              )
      ),
      # -------------------- GLOBAL DESIGN SPACE (CQA DYNAMIC SPLOM) --------------------
      tabItem(tabName = "exploration",
              # ---- Boîte 1 : CQA import (scrollable) ----
              fluidRow(
                box(width = 12, title = "CQA import", status = "warning", solidHeader = TRUE,
                    p("Add as many CQA as needed. For each CQA: set a name and upload a CSV."),
                    div(class = "cqa-scroll",
                        uiOutput("cqa_pred_ui_gd") # UI des CQA (nom, fichier, remove) - version Global DS
                    ),
                    actionButton("add_cqa_pred_gd", "➕ Add CQA")
                )
              ),
              # ---- Boîte 2 : Options (simplifiées) ----
              fluidRow(
                box(width = 12, title = "Options", status = "info", solidHeader = TRUE,
                    # Ligne 1 : Valeur associée
                    fluidRow(
                      column(12, selectInput("color_var_gd", "Associated value (color)",
                                             choices = NULL, selected = NULL))
                    ),
                    # Ligne 2 : Sélection des dimensions
                    fluidRow(
                      column(12,
                             selectizeInput("dims_gd", "Columns to use in the graph",
                                            choices = NULL, selected = NULL, multiple = TRUE,
                                            options = list(plugins = list("remove_button")))
                      )
                    ),
                    # Ligne 3 : Palette + couleurs custom
                    fluidRow(
                      column(4, selectInput("palette_gd", "Color palette",
                                            choices = c(
                                              "Custom",
                                              "Blackbody", "Bluered", "Cividis", "Cool", "Cubehelix", "Earth", "Electric",
                                              "Greys", "Hot", "Inferno", "Jet", "Magma", "Picnic", "Plasma", "Portland",
                                              "Rainbow", "RdBu", "Viridis", "YlGnBu", "YlOrRd"
                                            ),
                                            selected = "Custom")),
                      column(4,
                             conditionalPanel(
                               condition = "input.palette_gd == 'Custom'",
                               colourpicker::colourInput("custom_color_0_gd", "Color for 0", value = "red")
                             )
                      ),
                      column(4,
                             conditionalPanel(
                               condition = "input.palette_gd == 'Custom'",
                               colourpicker::colourInput("custom_color_1_gd", "Color for 1", value = "green")
                             )
                      )
                    )
                )
              ),
              # ---- Boîte 3 : Résultats = SPLOM par CQA (un onglet par CQA) ----
              fluidRow(
                box(width = 12, title = "Global design space (scatter plot matrix)", status = "success", solidHeader = TRUE,
                    uiOutput("pred_tabs_gd")
                )
              )
      ),
      # -------------------- DESIGN SPACE (CQA DYNAMIQUE) --------------------
      tabItem(tabName = "prediction",
              # ---- Boîte 1 : CQA import (scrollable) ----
              fluidRow(
                box(width = 12, title = "CQA import", status = "warning", solidHeader = TRUE,
                    p("Add as many CQA as needed. For each CQA: set a name, upload a CSV, and define the acceptance limit."),
                    div(class = "cqa-scroll",
                        uiOutput("cqa_pred_ui") # UI des CQA (nom, fichier, type, seuil)
                    ),
                    actionButton("add_cqa_pred", "➕ Add CQA")
                )
              ),
              # ---- Boîte 2 : Options globales ----
              fluidRow(
                box(width = 12, title = "Options", status = "info", solidHeader = TRUE,
                    fluidRow(
                      column(3, numericInput("n_intervals", "Number of facet intervals:", value = 4, min = 1, step = 1)),
                      column(3, checkboxInput("use_ci", "Use confidence intervals (95% CI)", value = FALSE)),
                      column(2, selectInput("facet_var", "Facet by", choices = NULL, selected = NULL)),
                      column(2, selectInput("x_var", "X axis", choices = NULL, selected = NULL)),
                      column(2, selectInput("y_var", "Y axis", choices = NULL, selected = NULL))
                    ),
                    fluidRow(
                      column(3, selectInput("palette_pred", "Color palette",
                                            choices = c(
                                              "Custom",
                                              "Blackbody", "Bluered", "Cividis", "Cool", "Cubehelix", "Earth", "Electric",
                                              "Greys", "Hot", "Inferno", "Jet", "Magma", "Picnic", "Plasma", "Portland",
                                              "Rainbow", "RdBu", "Viridis", "YlGnBu", "YlOrRd"
                                            ),
                                            selected = "Custom")),
                      column(3,
                             conditionalPanel(
                               condition = "input.palette_pred == 'Custom'",
                               colourpicker::colourInput("custom_color_0_pred", "Color for 0", value = "red")
                             )
                      ),
                      column(3,
                             conditionalPanel(
                               condition = "input.palette_pred == 'Custom'",
                               colourpicker::colourInput("custom_color_1_pred", "Color for 1", value = "green")
                             )
                      ),
                      column(3, selectInput("ggplot_theme", "Thème ggplot",
                                            choices = c("minimal", "classic", "gray", "bw", "light", "dark", "void"),
                                            selected = "minimal"))
                    )
                )
              ),
              # ---- Boîte 3 : Prediction results (onglets dynamiques + Synthesis) ----
              fluidRow(
                box(width = 12, title = "Prediction results", status = "success", solidHeader = TRUE,
                    uiOutput("pred_tabs") # un onglet par CQA + onglet Synthesis
                )
              )
      )
    )
  )
)

server <- function(input, output, session) {
  
  # ---------- Palette helpers ----------
  get_palette <- function(name) {
    switch(name,
           "Viridis" = "Viridis",
           "Cividis" = "Cividis",
           "Plasma"  = "Plasma",
           "Inferno" = "Inferno",
           "Magma"   = "Magma",
           "Rainbow" = "Rainbow",
           "Jet"     = "Jet",
           "Hot"     = "Hot",
           "Cool"    = "Cool",
           "Cubehelix" = "Cubehelix",
           "Earth"   = "Earth",
           "Electric"= "Electric",
           "Greys"   = "Greys",
           "YlGnBu"  = "YlGnBu",
           "YlOrRd"  = "YlOrRd",
           "Bluered" = "Bluered",
           "RdBu"    = "RdBu",
           "Picnic"  = "Picnic",
           "Portland"= "Portland",
           "Blackbody" = "Blackbody",
           "Custom"  = NULL
    )
  }
  get_binary_colors <- function(palette_name) {
    if (palette_name == "Custom") {
      col0 <- input$custom_color_0_pred
      col1 <- input$custom_color_1_pred
      if (is.null(col0) || is.null(col1)) return(c("0" = "red", "1" = "green"))
      return(c("0" = col0, "1" = col1))
    }
    switch(palette_name,
           "Viridis" = c("0" = "#440154", "1" = "#21908C"),
           "Cividis" = c("0" = "#00224E", "1" = "#FDE725"),
           "Plasma"  = c("0" = "#0D0887", "1" = "#F0F921"),
           "Inferno" = c("0" = "#000004", "1" = "#FCFDBF"),
           "Magma"   = c("0" = "#000004", "1" = "#FBF4F9"),
           "Rainbow" = c("0" = "#E60000", "1" = "#00E6E6"),
           "Jet"     = c("0" = "#00007F", "1" = "#FF7F00"),
           "Hot"     = c("0" = "#0B0000", "1" = "#FFFC00"),
           "Cool"    = c("0" = "#00FFFF", "1" = "#FF00FF"),
           "Cubehelix" = c("0" = "#000000", "1" = "#FFFFFF"),
           "Earth"   = c("0" = "#A16928", "1" = "#D9E6EB"),
           "Electric"= c("0" = "#0000FF", "1" = "#FFFF00"),
           "Greys"   = c("0" = "#333333", "1" = "#CCCCCC"),
           "YlGnBu"  = c("0" = "#FFFFCC", "1" = "#1C9099"),
           "YlOrRd"  = c("0" = "#FFFFB2", "1" = "#D7191C"),
           "Bluered" = c("0" = "#3B4CC0", "1" = "#B40426"),
           "RdBu"    = c("0" = "#B2182B", "1" = "#2166AC"),
           "Picnic"  = c("0" = "#FF0000", "1" = "#00FF00"),
           "Portland"= c("0" = "#0C3383", "1" = "#FEE08B"),
           "Blackbody" = c("0" = "#000000", "1" = "#FFFFFF"),
           "Custom"  = c("0" = "red", "1" = "green")
    )
  }
  get_theme <- function(theme_name) {
    switch(theme_name,
           "minimal" = theme_minimal(),
           "classic" = theme_classic(),
           "gray"    = theme_gray(),
           "bw"      = theme_bw(),
           "light"   = theme_light(),
           "dark"    = theme_dark(),
           "void"    = theme_void(),
           theme_minimal() # fallback
    )
  }
  
  # ---------- PARAMETER MANAGEMENT ----------
  params <- reactiveVal(
    data.frame(
      id = 1,
      excipient = "",
      range = FALSE,
      val = 0,
      min = 0,
      max = 10,
      unit = "mM",
      stringsAsFactors = FALSE
    )
  )
  read_params_from_ui <- function(df) {
    if (is.null(df) || nrow(df) == 0) return(df)
    out <- df
    for (j in seq_len(nrow(df))) {
      id <- df$id[j]
      ex <- input[[paste0("excipient_", id)]]
      if (!is.null(ex)) out$excipient[j] <- ex
      rng <- input[[paste0("range_", id)]]
      if (!is.null(rng)) out$range[j] <- isTRUE(rng)
      v <- input[[paste0("val_", id)]]
      if (!is.null(v)) out$val[j] <- v
      mn <- input[[paste0("min_", id)]]
      if (!is.null(mn)) out$min[j] <- mn
      mx <- input[[paste0("max_", id)]]
      if (!is.null(mx)) out$max[j] <- mx
      u <- input[[paste0("unit_", id)]]
      if (!is.null(u)) out$unit[j] <- u
    }
    out
  }
  observeEvent(input$add_param, {
    df <- params()
    df <- read_params_from_ui(df)
    new_row <- data.frame(
      id = ifelse(nrow(df) == 0, 1, max(df$id) + 1),
      excipient = "",
      range = FALSE,
      val = 0,
      min = 0,
      max = 10,
      unit = "mM",
      stringsAsFactors = FALSE
    )
    df <- rbind(df, new_row)
    df$id <- seq_len(nrow(df))
    params(df)
  })
  observeEvent(input$delete_row, {
    id_to_delete <- as.numeric(input$delete_row)
    if (is.na(id_to_delete)) return()
    df <- params()
    df <- read_params_from_ui(df)
    if (id_to_delete %in% df$id) {
      df <- df[df$id != id_to_delete, , drop = FALSE]
      if (nrow(df) > 0) {
        df$id <- seq_len(nrow(df))
      } else {
        df <- data.frame(
          id = integer(0), excipient = character(0), range = logical(0),
          val = numeric(0), min = numeric(0), max = numeric(0),
          unit = character(0), stringsAsFactors = FALSE
        )
      }
      params(df)
    }
    session$sendInputMessage("delete_row", NULL)
  })
  output$param_table_ui <- renderUI({
    df <- params()
    header <- fluidRow(
      column(1, strong("Name")),
      column(4, strong("Excipient name")),
      column(3, strong("Concentration (fixed by default)")),
      column(2, strong("Unit")),
      column(2, strong("Remove"))
    )
    if (nrow(df) == 0) {
      return(tagList(header, tags$hr(), p("No parameters yet.")))
    }
    rows <- lapply(seq_len(nrow(df)), function(i) {
      id <- df$id[i]
      fluidRow(class = "param-row",
               column(1, tags$div(style = "margin-top:10px;", strong(paste0("X", i)))),
               column(4, textInput(paste0("excipient_", id), label = NULL,
                                   value = df$excipient[i], placeholder = "e.g. Proline")),
               column(3,
                      checkboxInput(paste0("range_", id), "Use range?", value = isTRUE(df$range[i])),
                      conditionalPanel(
                        condition = paste0("input.range_", id, " == false"),
                        numericInput(paste0("val_", id), label = "Fixed value", value = df$val[i])
                      ),
                      conditionalPanel(
                        condition = paste0("input.range_", id, " == true"),
                        fluidRow(
                          column(6, numericInput(paste0("min_", id), "Min", value = df$min[i])),
                          column(6, numericInput(paste0("max_", id), "Max", value = df$max[i]))
                        )
                      )
               ),
               column(2, selectInput(paste0("unit_", id), label = NULL,
                                     choices = c("mM", "mg/mL"), selected = df$unit[i])),
               column(2, br(),
                      tags$button(type = "button", class = "btn btn-danger btn-sm",
                                  onclick = sprintf("Shiny.setInputValue('delete_row', %d, {priority: 'event'})", id),
                                  icon("trash"))
               )
      )
    })
    tagList(header, tags$hr(), rows)
  })
  
  # ---------- RANDOMIZATION: SIMULATION ----------
  df_sim <- eventReactive(input$run_simu, {
    df <- params()
    if (nrow(df) == 0) return(NULL)
    df <- read_params_from_ui(df)
    df$id <- seq_len(nrow(df))
    n_simu <- input$n_simu
    set.seed(input$seed)
    sim <- data.frame(matrix(nrow = n_simu, ncol = nrow(df)))
    for (i in seq_len(nrow(df))) {
      if (isTRUE(df$range[i])) {
        mn <- as.numeric(df$min[i]); mx <- as.numeric(df$max[i])
        if (is.na(mn)) mn <- 0
        if (is.na(mx)) mx <- mn + 1
        if (mn > mx) { tmp <- mn; mn <- mx; mx <- tmp }
        sim[, i] <- round(runif(n_simu, min = mn, max = mx), 4)
      } else {
        sim[, i] <- rep(as.numeric(df$val[i]), n_simu)
      }
    }
    base <- paste0("X", seq_len(nrow(df)))
    labels <- ifelse(nzchar(df$excipient),
                     paste0(base, " = ", df$excipient, " (", df$unit, ")"),
                     base)
    colnames(sim) <- labels
    sim
  })
  output$table_simu <- renderDT({
    req(df_sim())
    DT::datatable(df_sim(), options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })
  output$download_simu <- downloadHandler(
    filename = function() "df_simulations.csv",
    content = function(file) {
      req(df_sim()); write.csv(df_sim(), file, row.names = FALSE)
    }
  )
  
  # ========== GLOBAL DESIGN SPACE (CQA-based SPLOM) ==========
  cqa_pred_gd <- reactiveVal(
    data.frame(
      id = 1L,
      name = "CQA_1",
      stringsAsFactors = FALSE
    )
  )
  cqa_ui_version_gd <- reactiveVal(0L) # re-render Import UI seulement sur add/remove
  read_cqa_pred_from_ui_gd <- function(df) {
    if (is.null(df) || nrow(df) == 0) return(df)
    out <- df
    for (i in seq_len(nrow(df))) {
      id <- df$id[i]
      nm <- input[[paste0("cqa_name_gd_", id)]]
      if (!is.null(nm)) out$name[i] <- nm
    }
    out
  }
  observeEvent(input$add_cqa_pred_gd, {
    df <- read_cqa_pred_from_ui_gd(cqa_pred_gd())
    new_row <- data.frame(
      id = ifelse(nrow(df) == 0, 1L, max(df$id) + 1L),
      name = paste0("CQA_", nrow(df) + 1L),
      stringsAsFactors = FALSE
    )
    df <- rbind(df, new_row)
    df$id <- seq_len(nrow(df))
    cqa_pred_gd(df)
    cqa_ui_version_gd(cqa_ui_version_gd() + 1L)
    updateTabsetPanel(session, "pred_tabs_gd_id", selected = df$name[nrow(df)])
  })
  observeEvent(input$delete_cqa_pred_gd, {
    id_to_delete <- as.numeric(input$delete_cqa_pred_gd)
    if (is.na(id_to_delete)) return()
    df <- read_cqa_pred_from_ui_gd(cqa_pred_gd())
    if (id_to_delete %in% df$id) {
      df <- df[df$id != id_to_delete, , drop = FALSE]
      if (nrow(df) > 0) df$id <- seq_len(nrow(df))
      cqa_pred_gd(df)
      cqa_ui_version_gd(cqa_ui_version_gd() + 1L)
    }
    session$sendInputMessage("delete_cqa_pred_gd", NULL)
  })
  output$cqa_pred_ui_gd <- renderUI({
    v <- cqa_ui_version_gd() # dépendance add/remove
    df <- isolate(read_cqa_pred_from_ui_gd(cqa_pred_gd()))
    if (is.null(df) || nrow(df) == 0) return(p("No CQA yet. Click 'Add CQA' to start."))
    rows <- lapply(seq_len(nrow(df)), function(i) {
      id <- df$id[i]
      fluidRow(class = "cqa-row",
               column(6, textInput(paste0("cqa_name_gd_", id), "CQA name", value = df$name[i])),
               column(4, fileInput(paste0("cqa_file_gd_", id), "CSV file", accept = ".csv")),
               column(2, br(),
                      tags$button(type = "button", class = "btn btn-danger btn-sm",
                                  onclick = sprintf("Shiny.setInputValue('delete_cqa_pred_gd', %d, {priority: 'event'})", id),
                                  icon("trash"), " Remove")
               )
      )
    })
    tagList(rows)
  })
  read_csv_gd <- function(file_input) {
    if (is.null(file_input)) return(NULL)
    df <- tryCatch(
      read.csv(file_input$datapath, header = TRUE, check.names = FALSE, strip.white = TRUE),
      error = function(e) NULL
    )
    if (is.null(df) || nrow(df) == 0) return(NULL)
    if (length(names(df)) > 0) names(df)[1] <- sub("^\ufeff", "", names(df)[1])
    df
  }
  cqa_selected_id_gd <- reactive({
    df <- read_cqa_pred_from_ui_gd(cqa_pred_gd())
    if (is.null(df) || nrow(df) == 0) return(NULL)
    sel <- input$pred_tabs_gd_id
    if (is.null(sel)) return(df$id[1])
    row <- df[df$name == sel, , drop = FALSE]
    if (nrow(row) == 1) row$id else df$id[1]
  })
  cqa_current_data_gd <- reactive({
    id <- cqa_selected_id_gd(); if (is.null(id)) return(NULL)
    file_in <- input[[paste0("cqa_file_gd_", id)]]
    read_csv_gd(file_in)
  })
  observeEvent(cqa_current_data_gd(), {
    dat <- cqa_current_data_gd()
    if (is.null(dat)) {
      empty <- setNames(character(0), character(0))
      updateSelectInput(session, "color_var_gd", choices = empty, selected = NULL)
      updateSelectInput(session, "dims_gd", choices = empty, selected = NULL)
      return()
    }
    cols <- names(dat)
    default_color <- if (length(cols) >= 2) cols[length(cols) - 1] else cols[1]
    default_dims  <- if (length(cols) >= 2) cols[seq_len(length(cols) - 2)] else cols
    keep_or <- function(cur, choices, def) if (!is.null(cur) && all(cur %in% choices)) cur else def
    sel_color <- keep_or(isolate(input$color_var_gd), cols, default_color)
    sel_dims  <- keep_or(isolate(input$dims_gd), cols, default_dims)
    choices_named <- stats::setNames(cols, cols)
    updateSelectInput(session, "color_var_gd", choices = choices_named, selected = sel_color)
    updateSelectInput(session, "dims_gd", choices = choices_named, selected = sel_dims)
  }, ignoreInit = FALSE)
  build_splom_gd <- function(df, dims, color_col = NULL, title = NULL) {
    if (is.null(df) || !is.data.frame(df) || is.null(dims) || length(dims) < 2) return(NULL)
    dims <- dims[dims %in% names(df)]
    if (length(dims) < 2) return(NULL)
    df_num <- df[dims]
    for (nm in names(df_num)) {
      if (!is.numeric(df_num[[nm]])) {
        suppressWarnings(df_num[[nm]] <- as.numeric(as.character(df_num[[nm]])))
      }
    }
    num_cols <- names(df_num)[vapply(df_num, is.numeric, logical(1))]
    if (length(num_cols) < 2) return(NULL)
    dims_pl <- lapply(num_cols, function(x) list(label = x, values = df_num[[x]]))
    marker <- list(size = 5, opacity = 0.7)
    if (!is.null(color_col) && color_col %in% names(df)) {
      colv <- df[[color_col]]
      if (is.factor(colv)) colv <- as.numeric(colv)
      if (!is.numeric(colv)) {
        suppressWarnings(colv <- as.numeric(as.character(colv)))
      }
      marker$color <- colv
      if (input$palette_gd == "Custom") {
        col0 <- input$custom_color_0_gd
        col1 <- input$custom_color_1_gd
        if (is.null(col0) || is.null(col1)) {
          marker$colorscale <- list(c(0, "red"), c(1, "green"))
        } else {
          marker$colorscale <- list(c(0, col0), c(1, col1))
        }
      } else {
        marker$colorscale <- get_palette(input$palette_gd)
      }
      marker$showscale <- TRUE
    } else {
      marker$color <- "steelblue"
      marker$showscale <- FALSE
    }
    plotly::plot_ly(type = "splom", dimensions = dims_pl, marker = marker) %>%
      layout(
        title = list(text = if (!is.null(title)) title else "Scatter plot matrix", x = 0.5, xanchor = "center"),
        dragmode = "select", hovermode = "closest"
      )
  }
  output$pred_tabs_gd <- renderUI({
    df <- read_cqa_pred_from_ui_gd(cqa_pred_gd())
    if (is.null(df) || nrow(df) == 0) {
      return(tabsetPanel(tabPanel("No CQA", p("No CQA defined yet."))))
    }
    tabs <- lapply(seq_len(nrow(df)), function(i) {
      id <- df$id[i]; nm <- df$name[i]
      tabPanel(
        title = nm,
        fluidRow(
          column(width = 12, plotlyOutput(paste0("cqa_splom_gd_", id), height = "700px"))
        )
      )
    })
    do.call(tabsetPanel, c(tabs, id = "pred_tabs_gd_id"))
  })
  observe({
    df <- read_cqa_pred_from_ui_gd(cqa_pred_gd())
    if (nrow(df) == 0) return(NULL)
    lapply(seq_len(nrow(df)), function(i) {
      id <- df$id[i]
      local({
        .id <- id
        output[[paste0("cqa_splom_gd_", .id)]] <- renderPlotly({
          cfg <- read_cqa_pred_from_ui_gd(cqa_pred_gd())
          row <- cfg[cfg$id == .id, , drop = FALSE]
          file_in <- input[[paste0("cqa_file_gd_", .id)]]
          dat <- read_csv_gd(file_in)
          req(dat)
          build_splom_gd(dat,
                         dims = input$dims_gd,
                         color_col = input$color_var_gd,
                         title = row$name)
        })
      })
    })
  })
  
  # ========== DESIGN SPACE : CQA DYNAMIQUE ==========
  cqa_pred <- reactiveVal(
    data.frame(
      id = 1L,
      name = "CQA_1",
      limit_type = "lower", # "lower" ou "upper"
      threshold = 0,        # numérique
      stringsAsFactors = FALSE
    )
  )
  cqa_ui_version <- reactiveVal(0L)
  read_cqa_pred_from_ui <- function(df) {
    if (is.null(df) || nrow(df) == 0) return(df)
    out <- df
    for (i in seq_len(nrow(df))) {
      id <- df$id[i]
      nm <- input[[paste0("cqa_name_", id)]]; if (!is.null(nm)) out$name[i] <- nm
      lt <- input[[paste0("cqa_limit_type_", id)]]; if (!is.null(lt)) out$limit_type[i] <- lt
      th <- input[[paste0("cqa_threshold_", id)]]; if (!is.null(th)) out$threshold[i] <- suppressWarnings(as.numeric(th))
    }
    out
  }
  observeEvent(input$add_cqa_pred, {
    df <- read_cqa_pred_from_ui(cqa_pred())
    new_row <- data.frame(
      id = ifelse(nrow(df) == 0, 1L, max(df$id) + 1L),
      name = paste0("CQA_", nrow(df) + 1L),
      limit_type = "lower",
      threshold = 0,
      stringsAsFactors = FALSE
    )
    df <- rbind(df, new_row)
    df$id <- seq_len(nrow(df))
    cqa_pred(df)
    cqa_ui_version(cqa_ui_version() + 1L)
    updateTabsetPanel(session, "pred_tabs_id", selected = df$name[nrow(df)])
  })
  observeEvent(input$delete_cqa_pred, {
    id_to_delete <- as.numeric(input$delete_cqa_pred)
    if (is.na(id_to_delete)) return()
    df <- read_cqa_pred_from_ui(cqa_pred())
    if (id_to_delete %in% df$id) {
      df <- df[df$id != id_to_delete, , drop = FALSE]
      if (nrow(df) > 0) df$id <- seq_len(nrow(df))
      cqa_pred(df)
      cqa_ui_version(cqa_ui_version() + 1L)
    }
    session$sendInputMessage("delete_cqa_pred", NULL)
  })
  output$cqa_pred_ui <- renderUI({
    v <- cqa_ui_version()
    df <- isolate(read_cqa_pred_from_ui(cqa_pred()))
    if (is.null(df) || nrow(df) == 0) return(p("No CQA yet. Click 'Add CQA' to start."))
    rows <- lapply(seq_len(nrow(df)), function(i) {
      id <- df$id[i]
      fluidRow(class = "cqa-row",
               column(3, textInput(paste0("cqa_name_", id), "CQA name", value = df$name[i])),
               column(4, fileInput(paste0("cqa_file_", id), "CSV file", accept = ".csv")),
               column(3,
                      selectInput(paste0("cqa_limit_type_", id), "Acceptance limit type",
                                  choices = c("Upper limit" = "upper", "Lower limit" = "lower"),
                                  selected = df$limit_type[i]),
                      numericInput(paste0("cqa_threshold_", id), "Threshold", value = df$threshold[i], step = 0.1)
               ),
               column(2, br(),
                      tags$button(type = "button", class = "btn btn-danger btn-sm",
                                  onclick = sprintf("Shiny.setInputValue('delete_cqa_pred', %d, {priority: 'event'})", id),
                                  icon("trash"), " Remove")
               )
      )
    })
    tagList(rows)
  })
  
  # ---- Lecture CSV SANS renommer les colonnes (last-1=Pred, last=CI) ----
  process_prediction_general <- function(file_input, seuil, limit_type = c("lower","upper"), use_ci = FALSE) {
    if (is.null(file_input)) return(NULL)
    df <- tryCatch(read.csv(file_input$datapath, header = TRUE, check.names = FALSE, strip.white = TRUE),
                   error = function(e) NULL)
    if (is.null(df) || nrow(df) == 0 || ncol(df) < 2) return(NULL)
    if (length(names(df)) > 0) names(df)[1] <- sub("^\ufeff", "", names(df)[1])
    p <- ncol(df)
    pred_col <- names(df)[p - 1]
    ci_col   <- names(df)[p]
    suppressWarnings({
      df[[pred_col]] <- as.numeric(df[[pred_col]])
      df[[ci_col]]   <- as.numeric(df[[ci_col]])
    })
    df[[ci_col]][is.na(df[[ci_col]])] <- 0
    limit_type <- match.arg(limit_type)
    if (use_ci) {
      if (limit_type == "lower") df$target <- ifelse(df[[pred_col]] - df[[ci_col]] >= seuil, 1, 0)
      else                       df$target <- ifelse(df[[pred_col]] + df[[ci_col]] <= seuil, 1, 0)
    } else {
      if (limit_type == "lower") df$target <- ifelse(df[[pred_col]] >= seuil, 1, 0)
      else                       df$target <- ifelse(df[[pred_col]] <= seuil, 1, 0)
    }
    df$target <- as.factor(df$target)
    df
  }
  
  # ---- CQA actif & données traitées (pour alimenter sélecteurs Facet/X/Y) ----
  cqa_selected_id <- reactive({
    df <- read_cqa_pred_from_ui(cqa_pred())
    if (is.null(df) || nrow(df) == 0) return(NULL)
    sel <- input$pred_tabs_id
    if (is.null(sel)) return(df$id[1])
    row <- df[df$name == sel, , drop = FALSE]
    if (nrow(row) == 1) row$id else df$id[1]
  })
  cqa_current_data <- reactive({
    id <- cqa_selected_id(); if (is.null(id)) return(NULL)
    cfg <- read_cqa_pred_from_ui(cqa_pred())
    row <- cfg[cfg$id == id, , drop = FALSE]
    file_in <- input[[paste0("cqa_file_", id)]]
    if (is.null(file_in)) return(NULL)
    use_ci <- isTRUE(input$use_ci)
    limit_t <- if (nrow(row)) row$limit_type else "lower"
    seuil   <- if (nrow(row)) row$threshold  else 0
    process_prediction_general(file_in, seuil, limit_type = limit_t, use_ci = use_ci)
  })
  
  # ---- Alimente les sélecteurs Facet / X / Y ----
  observeEvent(cqa_current_data(), {
    dat <- cqa_current_data()
    if (is.null(dat)) {
      empty <- setNames(character(0), character(0))
      updateSelectInput(session, "facet_var", choices = empty, selected = NULL)
      updateSelectInput(session, "x_var", choices = empty, selected = NULL)
      updateSelectInput(session, "y_var", choices = empty, selected = NULL)
      return()
    }
    cols <- setdiff(names(dat), "target")
    default_f <- if (length(cols) >= 1) cols[1] else NULL
    default_x <- if (length(cols) >= 2) cols[2] else default_f
    default_y <- if (length(cols) >= 3) cols[3] else default_x
    keep_or <- function(cur, choices, def) if (!is.null(cur) && cur %in% choices) cur else def
    sel_f <- keep_or(isolate(input$facet_var), cols, default_f)
    sel_x <- keep_or(isolate(input$x_var), cols, default_x)
    sel_y <- keep_or(isolate(input$y_var), cols, default_y)
    choices_named <- stats::setNames(cols, cols)
    updateSelectInput(session, "facet_var", choices = choices_named, selected = sel_f)
    updateSelectInput(session, "x_var", choices = choices_named, selected = sel_x)
    updateSelectInput(session, "y_var", choices = choices_named, selected = sel_y)
  }, ignoreInit = FALSE)
  
  # ---- Création du plot ggplotly (utilisé par onglets CQA & Synthesis) ----
  create_plot <- function(data, title, n_intervals = 4,
                          facet_var, x_var, y_var,
                          axis_font_size = 14, facet_font_size = NULL, title_font_size = 18) {
    if (is.null(data)) return(NULL)
    cols <- names(data)
    f_ok <- !is.null(facet_var) && facet_var %in% cols
    x_ok <- !is.null(x_var)    && x_var %in% cols
    y_ok <- !is.null(y_var)    && y_var %in% cols
    if (!x_ok || !y_ok) {
      base_cols <- setdiff(cols, "target")
      if (length(base_cols) < 2) return(NULL)
      x_var <- base_cols[1]; y_var <- base_cols[2]
    }
    if (!is.numeric(data[[x_var]])) suppressWarnings(data[[x_var]] <- as.numeric(as.character(data[[x_var]])))
    if (!is.numeric(data[[y_var]])) suppressWarnings(data[[y_var]] <- as.numeric(as.character(data[[y_var]])))
    facet_info <- if (f_ok) paste0("Facet by: ", facet_var) else "Facet by: None"
    
    if (f_ok) {
      v <- data[[facet_var]]
      if (is.numeric(v)) {
        breaks <- seq(min(v, na.rm = TRUE), max(v, na.rm = TRUE), length.out = n_intervals + 1)
        data[[".facet_cut"]] <- cut(v, breaks = breaks, include.lowest = TRUE, right = FALSE)
        p <- ggplot(data, aes(x = .data[[x_var]], y = .data[[y_var]], color = .data[["target"]])) +
          geom_point(alpha = 0.7) +
          scale_color_manual(values = get_binary_colors(input$palette_pred)) +
          facet_wrap(~ .facet_cut) +
          ggtitle(title) +
          labs(x = x_var, y = y_var) +
          get_theme(input$ggplot_theme)
      } else {
        data[[".facet_cat"]] <- as.factor(v)
        p <- ggplot(data, aes(x = .data[[x_var]], y = .data[[y_var]], color = .data[["target"]])) +
          geom_point(alpha = 0.7) +
          scale_color_manual(values = get_binary_colors(input$palette_pred)) +
          facet_wrap(~ .facet_cat) +
          ggtitle(title) +
          labs(x = x_var, y = y_var) +
          get_theme(input$ggplot_theme)
      }
    } else {
      p <- ggplot(data, aes(x = .data[[x_var]], y = .data[[y_var]], color = .data[["target"]])) +
        geom_point(alpha = 0.7) +
        scale_color_manual(values = get_binary_colors(input$palette_pred)) +
        ggtitle(title) +
        labs(x = x_var, y = y_var) +
        get_theme(input$ggplot_theme)
    }
    
    gp <- ggplotly(p)
    gp <- gp %>% layout(
      title = list(text = title, x = 0.5, xanchor = "center", font = list(size = title_font_size)),
      margin = list(t = 90)
    )
    if (is.null(facet_font_size)) facet_font_size <- axis_font_size
    gp <- gp %>% layout(
      annotations = list(
        list(
          text = facet_info,
          x = 0.5, y = 1.08, xref = "paper", yref = "paper",
          showarrow = FALSE, xanchor = "center",
          font = list(size = facet_font_size, color = "#333333")
        )
      )
    )
    gp
  }
  
  # ---- Onglets CQA ----
  output$pred_tabs <- renderUI({
    df <- read_cqa_pred_from_ui(cqa_pred())
    if (nrow(df) == 0) {
      return(tabsetPanel(tabPanel("No CQA", p("No CQA defined yet."))))
    }
    tabs <- lapply(seq_len(nrow(df)), function(i) {
      id <- df$id[i]; nm <- df$name[i]
      tabPanel(
        title = nm,
        fluidRow(
          column(width = 5, DTOutput(paste0("cqa_table_", id))),
          column(width = 7, plotlyOutput(paste0("cqa_plot_", id), height = "500px"))
        )
      )
    })
    
    # ---- Onglet Synthesis (ajouté ici) ----
    tabs <- c(
      tabs,
      list(
        tabPanel(
          title = "Synthesis",
          fluidRow(
            column(width = 5, DTOutput("synth_table")),
            column(width = 7, plotlyOutput("synth_plot", height = "500px"))
          )
        )
      )
    )
    do.call(tabsetPanel, c(tabs, id = "pred_tabs_id"))
  })
  
  # ---- Rendus table/plot par CQA ----
  observe({
    df_cfg <- read_cqa_pred_from_ui(cqa_pred())
    if (nrow(df_cfg) == 0) return(NULL)
    lapply(seq_len(nrow(df_cfg)), function(i) {
      id <- df_cfg$id[i]; nm <- df_cfg$name[i]
      local({
        .id <- id; .nm <- nm
        output[[paste0("cqa_table_", .id)]] <- renderDT({
          cfg <- read_cqa_pred_from_ui(cqa_pred()); row <- cfg[cfg$id == .id, , drop = FALSE]
          file_in <- input[[paste0("cqa_file_", .id)]]
          use_ci <- isTRUE(input$use_ci)
          limit_t <- if (nrow(row)) row$limit_type else "lower"
          seuil   <- if (nrow(row)) row$threshold  else 0
          dat <- process_prediction_general(file_in, seuil, limit_type = limit_t, use_ci = use_ci)
          req(dat)
          datatable(dat, options = list(scrollX = TRUE, pageLength = 10))
        })
        output[[paste0("cqa_plot_", .id)]] <- renderPlotly({
          cfg <- read_cqa_pred_from_ui(cqa_pred()); row <- cfg[cfg$id == .id, , drop = FALSE]  # <- correction bug
          file_in <- input[[paste0("cqa_file_", .id)]]
          use_ci <- isTRUE(input$use_ci)
          limit_t <- if (nrow(row)) row$limit_type else "lower"
          seuil   <- if (nrow(row)) row$threshold  else 0
          dat <- process_prediction_general(file_in, seuil, limit_type = limit_t, use_ci = use_ci)
          req(dat)
          create_plot(dat,
                      title = .nm,
                      n_intervals = input$n_intervals,
                      facet_var = input$facet_var,
                      x_var = input$x_var,
                      y_var = input$y_var)
        })
      })
    })
  })
  
  # ================== SYNTHESE (nouveau) ==================
  # 1) Récupère toutes les données CQA traitées (avec target calculé)
  all_cqa_data <- reactive({
    cfg <- read_cqa_pred_from_ui(cqa_pred())
    if (is.null(cfg) || nrow(cfg) == 0) return(list())
    lst <- lapply(seq_len(nrow(cfg)), function(i) {
      id <- cfg$id[i]; nm <- cfg$name[i]
      file_in <- input[[paste0("cqa_file_", id)]]
      if (is.null(file_in)) return(NULL)
      use_ci <- isTRUE(input$use_ci)
      limit_t <- cfg$limit_type[i]
      seuil   <- cfg$threshold[i]
      dat <- process_prediction_general(file_in, seuil, limit_type = limit_t, use_ci = use_ci)
      if (is.null(dat)) return(NULL)
      dat$.cqa_name <- nm
      dat
    })
    names(lst) <- cfg$name
    lst[!vapply(lst, is.null, logical(1))]
  })
  
  # 2) Construit la table de synthèse par jointure sur (Facet, X, Y)
  synthesis_data <- reactive({
    lst <- all_cqa_data()
    if (length(lst) < 2) return(NULL)  # besoin d'au moins 2 CQA pour une synthèse
    
    facet_var <- input$facet_var
    x_var <- input$x_var
    y_var <- input$y_var
    key <- c(if (!is.null(facet_var) && nzchar(facet_var)) facet_var, x_var, y_var)
    key <- key[!vapply(key, function(z) is.null(z) || !nzchar(z), logical(1))]
    if (length(key) < 2) return(NULL)  # au moins X et Y
    
    # toutes les dataframes doivent contenir les colonnes clés
    for (i in seq_along(lst)) {
      if (!all(key %in% names(lst[[i]]))) return(NULL)
    }
    
    # construit des df minimaux : clés + target (renommé par CQA)
    minis <- lapply(names(lst), function(nm) {
      df <- lst[[nm]][, c(key, "target"), drop = FALSE]
      # coerce clés numériques si nécessaire pour éviter '1' vs 1
      for (kk in key) {
        if (!is.numeric(df[[kk]])) suppressWarnings(df[[kk]] <- as.numeric(as.character(df[[kk]])))
      }
      names(df)[names(df) == "target"] <- paste0("target__", nm)
      df
    })
    
    # inner-join successif sur les clés (conserve les points communs)
    merged <- Reduce(function(d1, d2) merge(d1, d2, by = key, all = FALSE), minis)
    if (is.null(merged) || !nrow(merged)) return(NULL)
    
    tcols <- grep("^target__", names(merged), value = TRUE)
    # final_target = 1 si tous les CQA sont OK (tous == 1), 0 sinon
    merged$final_target <- ifelse(rowSums(merged[, tcols, drop = FALSE] == 1) == length(tcols), 1, 0)
    merged$final_target <- as.factor(merged$final_target)
    merged
  })
  
  # 3) Table + Plot de synthèse
  output$synth_table <- renderDT({
    dat <- synthesis_data()
    validate(
      need(!is.null(dat), "Need at least two CQA files with matching Facet/X/Y columns to compute the synthesis.")
    )
    DT::datatable(dat, options = list(scrollX = TRUE, pageLength = 10))
  })
  output$synth_plot <- renderPlotly({
    dat <- synthesis_data()
    validate(
      need(!is.null(dat), "Need at least two CQA files with matching Facet/X/Y columns to compute the synthesis.")
    )
    # on réutilise create_plot en renommant final_target -> target
    dat$target <- dat$final_target
    create_plot(dat,
                title = "Synthesis",
                n_intervals = input$n_intervals,
                facet_var = input$facet_var,
                x_var = input$x_var,
                y_var = input$y_var)
  })
  
  # ---------- SUMMARY placeholders (non utilisés) ----------
  # Ajoutez ici d'autres calculs/rendus si nécessaire.
  
}

shinyApp(ui, server)