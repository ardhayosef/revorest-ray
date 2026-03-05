# 01_initialize_h3_grid.R
# Revorest-Ray: Hierarchical Grid Initialization
# Objective: Generate nested H3 structure (Res 8, 10, & 12) for IKN AOI using H3 v4 API.

library(sf)
library(h3jsr)
library(dplyr)
library(here)
library(tidyr)

# Set project root
root_dir <- here()

# 1. Define IKN AOI (Center: Nusantara approx -0.9, 116.7)
center_lon <- 116.7
center_lat <- -0.9
dist_km <- 1 # Small scale for initial validation

cat("Defining AOI for IKN region (", dist_km * 2, "km span)...\n")
aoi_bbox <- st_bbox(c(xmin = center_lon - (dist_km/111), 
                      xmax = center_lon + (dist_km/111),
                      ymin = center_lat - (dist_km/111), 
                      ymax = center_lat + (dist_km/111)), 
                    crs = st_crs(4326)) %>%
  st_as_sfc()

# 2. Generate Landscape Grid (H3 Res 8: ~73 Ha)
cat("Generating Res 8 Grid...\n")
ids_res8 <- polygon_to_cells(aoi_bbox, res = 8)[[1]]

grid_res8 <- st_sf(
    h3_index_res8 = ids_res8,
    geometry = cell_to_polygon(ids_res8),
    crs = 4326
  ) %>%
  mutate(
    region_id = paste0("REV-R8-", h3_index_res8)
  )

# 3. Generate Token Grid (H3 Res 10: ~1.5 Ha)
cat("Generating Res 10 Grid...\n")
ids_res10 <- polygon_to_cells(aoi_bbox, res = 10)[[1]]

# Map Res 10 to Res 8
mapping_10_to_8 <- data.frame(
  h3_index_res10 = ids_res10,
  h3_index_res8 = get_parent(ids_res10, res = 8),
  stringsAsFactors = FALSE
)

grid_res10 <- st_sf(
    h3_index_res10 = mapping_10_to_8$h3_index_res10,
    geometry = cell_to_polygon(mapping_10_to_8$h3_index_res10),
    crs = 4326
  ) %>%
  left_join(mapping_10_to_8, by = "h3_index_res10") %>%
  mutate(
    token_id = paste0("REV-R10-", h3_index_res10),
    state = "FOG"
  )

# 4. Generate Scanner Grid (H3 Res 12: ~300 m2)
cat("Generating Res 12 Grid...\n")
# Using Res 10 as base for children to ensure relationship mapping
child_list <- lapply(ids_res10, function(p_id) {
  children <- get_children(p_id, res = 12)[[1]]
  data.frame(
    h3_index_res10 = p_id,
    h3_index_res12 = children,
    stringsAsFactors = FALSE
  )
})

mapping_12_to_10 <- bind_rows(child_list)

grid_res12 <- st_sf(
    h3_index_res12 = mapping_12_to_10$h3_index_res12,
    geometry = cell_to_polygon(mapping_12_to_10$h3_index_res12),
    crs = 4326
  ) %>%
  left_join(mapping_12_to_10, by = "h3_index_res12")

# 5. Save Structured Data
data_dir <- file.path(root_dir, "data")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

saveRDS(grid_res8,  file.path(data_dir, "ray_grid_res8.rds"))
saveRDS(grid_res10, file.path(data_dir, "ray_grid_res10.rds"))
saveRDS(grid_res12, file.path(data_dir, "ray_grid_res12.rds"))

st_write(grid_res8,  file.path(data_dir, "ray_grid_res8.gpkg"),  delete_dsn = TRUE)
st_write(grid_res10, file.path(data_dir, "ray_grid_res10.gpkg"), delete_dsn = TRUE)
st_write(grid_res12, file.path(data_dir, "ray_grid_res12.gpkg"), delete_dsn = TRUE)

cat("\n=== Revorest-Ray Grid Summary ===\n")
cat("Total Tiles Res 8: ", nrow(grid_res8), "\n")
cat("Total Tiles Res 10:", nrow(grid_res10), "\n")
cat("Total Tiles Res 12:", nrow(grid_res12), "\n")
cat("Success: Explicit resolution-based hierarchy initialized.\n")
