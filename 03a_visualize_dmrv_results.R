# 03a_visualize_dmrv_results.R
# Revorest-Ray: Final d-MRV Result Visualization (Bottom-Up Edition)
# Objective: Interactive map showing Verified Tokens, Micro-Classes, and Tree Counts

library(sf)
library(leaflet)
library(here)
library(dplyr)
library(viridis)

root_dir <- here()
data_dir <- file.path(root_dir, "data")
out_dir  <- file.path(data_dir, "output")

cat("Loading hierarchical analyzed results...\n")
res8_final  <- readRDS(file.path(out_dir, "revorest_final_res8.rds"))
res10_final <- readRDS(file.path(out_dir, "revorest_final_res10.rds"))
res12_final <- readRDS(file.path(data_dir, "ray_analyzed_res12.rds"))

# Transform to WGS84
res8_map  <- res8_final  %>% st_transform(4326)
res10_map <- res10_final %>% st_transform(4326)
res12_map <- res12_final %>% st_transform(4326)

# Define Color Palettes
pal_state <- colorFactor(
  palette = c("#2ecc71", "#f1c40f", "#e74c3c"), # Green, Yellow, Red
  levels = c("VERIFIED", "MONITORED", "EXPLORED")
)

pal_integrity <- colorNumeric(palette = "Greens", domain = c(0, 100))

# Micro-Class Palette for Res 12
pal_micro <- colorFactor(
  palette = c("#1b5e20", "#4caf50", "#ffeb3b", "#795548"), # Deep Green, Light Green, Yellow, Brown
  levels = c("Intact Forest", "Regrowing / Secondary", "Degraded / Gap", "Non-Forest / Ground")
)

cat("Generating interactive Precision d-MRV map...\n")

map <- leaflet() %>%
  addProviderTiles(providers$CartoDB.DarkMatter) %>% 
  
  # 1. Res 8 Layer (Landscape Overview)
  addPolygons(
    data = res8_map,
    fillColor = ~pal_integrity(landscape_avg_integrity),
    fillOpacity = 0.4,
    color = "white",
    weight = 2,
    group = "Landscape (Res 8)",
    label = ~paste0("Landscape Integrity: ", round(landscape_avg_integrity, 1), "%")
  ) %>%
  
  # 2. Res 10 Layer (Token Level)
  addPolygons(
    data = res10_map,
    fillColor = ~pal_state(state),
    fillOpacity = 0.6,
    color = "white",
    weight = 1,
    group = "Token Units (Res 10)",
    popup = ~paste0(
      "<div style='font-family: Arial; min-width: 200px;'>",
      "<h3 style='margin:0; color:#2ecc71;'>", state, " TOKEN</h3>",
      "<hr>",
      "<b>Token ID:</b> ", token_id, "<br>",
      "<b>Est. Tree Count:</b> ", format(estimated_tree_count, big.mark=","), " trees<br>",
      "<b>Biomass:</b> ", format(round(token_total_biomass_co2e, 1), big.mark=","), " tCO2e<br>",
      "<b>Integrity Score:</b> ", round(integrity_score, 1), "%<br>",
      "<b>Healthy Children:</b> ", healthy_child_count, "/49",
      "</div>"
    )
  ) %>%
  
  # 3. Res 12 Layer (Scanner Level - Precision Detail)
  addPolygons(
    data = res12_map,
    fillColor = ~pal_micro(micro_class),
    fillOpacity = 0.8,
    color = "white",
    weight = 0.2,
    group = "Scanner Detail (Res 12)",
    popup = ~paste0(
      "<div style='font-family: monospace; font-size: 12px;'>",
      "<b style='color:#2ecc71;'>SCANNER UNIT</b><br>",
      "Class: ", micro_class, "<br>",
      "Biomass: ", round(biomass_res12_co2e, 2), " tCO2e",
      "<hr>",
      "NDVI: ", round(ndvi_mean, 3), "<br>",
      "Radar VH: ", round(radar_vh, 2), " dB",
      "</div>"
    )
  ) %>%
  
  # Adaptive Zoom Rules
  groupOptions("Landscape (Res 8)", zoomLevels = 1:12) %>%
  groupOptions("Token Units (Res 10)", zoomLevels = 13:15) %>%
  groupOptions("Scanner Detail (Res 12)", zoomLevels = 16:20) %>%
  
  addLayersControl(
    overlayGroups = c("Landscape (Res 8)", "Token Units (Res 10)", "Scanner Detail (Res 12)"),
    options = layersControlOptions(collapsed = FALSE)
  ) %>%
  
  addLegend(
    position = "bottomright",
    pal = pal_state,
    values = c("VERIFIED", "MONITORED", "EXPLORED"),
    title = "Token Status"
  ) %>%
  
  addLegend(
    position = "bottomleft",
    pal = pal_micro,
    values = c("Intact Forest", "Regrowing / Secondary", "Degraded / Gap", "Non-Forest / Ground"),
    title = "Micro-Class (Scanner)"
  )

cat("Saving final precision map to: output/final_precision_ledger_map.html\n")
output_html <- file.path(root_dir, "output", "final_precision_ledger_map.html")
htmlwidgets::saveWidget(map, output_html)

cat("\n=== Final Precision Visualization Success ===\n")
cat("1. Bottom-Up results mapped.\n")
cat("2. Legend for micro-classification added.\n")
