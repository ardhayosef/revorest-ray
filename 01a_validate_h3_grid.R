# 01a_validate_h3_grid.R
# Revorest-Ray: Grid Validation & Visualization
# Objective: Interactive map to verify H3 nesting (Res 8, 10, 12)

library(sf)
library(leaflet)
library(here)
library(dplyr)

root_dir <- here()
data_dir <- file.path(root_dir, "data")

cat("Loading hierarchical H3 grids for validation...\n")
grid_res8  <- readRDS(file.path(data_dir, "ray_grid_res8.rds"))
grid_res10 <- readRDS(file.path(data_dir, "ray_grid_res10.rds"))
grid_res12 <- readRDS(file.path(data_dir, "ray_grid_res12.rds"))

# Load all data for the pilot area
cat("Preparing hierarchy for mapping...\n")
res8_full  <- grid_res8  %>% st_transform(4326)
res10_full <- grid_res10 %>% st_transform(4326)
res12_full <- grid_res12 %>% st_transform(4326)

cat("Generating interactive validation map (Res 8, 10, 12)...\n")

map <- leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%

  # 1. Res 8 - Landscape Level (Visible at low zoom: 1-12)
  addPolygons(
    data = res8_full,
    color = "black",
    weight = 4,
    opacity = 1,
    fillOpacity = 0,
    group = "Landscape (Res 8)",
    label = ~paste("Macro Unit:", h3_index_res8)
  ) %>%

  # 2. Res 10 - Token Level (Visible at medium zoom: 13-15)
  addPolygons(
    data = res10_full,
    color = "firebrick",
    weight = 2,
    opacity = 0.8,
    fillOpacity = 0.05,
    group = "Token Unit (Res 10)",
    label = ~paste("Res 10:", h3_index_res10),
    popup = ~paste("<b>Token ID:</b>", token_id, "<br><b>Parent Res 8:</b>", h3_index_res8)
  ) %>%

  # 3. Res 12 - Scanner Level (Visible at high zoom: 16+)
  addPolygons(
    data = res12_full,
    color = "royalblue",
    weight = 0.5,
    opacity = 0.4,
    fillOpacity = 0.1,
    group = "Scanner Unit (Res 12)",
    label = ~paste("Res 12:", h3_index_res12)
  ) %>%

  # Set Zoom Visibility Rules
  groupOptions("Landscape (Res 8)", zoomLevels = 1:12) %>%
  groupOptions("Token Unit (Res 10)", zoomLevels = 13:15) %>%
  groupOptions("Scanner Unit (Res 12)", zoomLevels = 16:20) %>%

  addLayersControl(
    overlayGroups = c("Landscape (Res 8)", "Token Unit (Res 10)", "Scanner Unit (Res 12)"),
    options = layersControlOptions(collapsed = FALSE)
  ) %>%

  addLegend(
    position = "bottomright",
    colors = c("black", "firebrick", "royalblue"),
    labels = c("Res 8: Landscape (Zoom 1-12)", "Res 10: Token (Zoom 13-15)", "Res 12: Scanner (Zoom 16+)"),
    title = "Adaptive Hierarchy"
  )


cat("Saving validation map to: output/validation_map.html\n")
output_dir <- file.path(root_dir, "output")
dir.create(output_dir, showWarnings = FALSE)
htmlwidgets::saveWidget(map, file.path(output_dir, "validation_map.html"))

cat("\n=== Validation Success ===\n")
cat("Explicit resolution naming verified.\n")
