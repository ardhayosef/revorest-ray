# 02b_process_results.R
# Revorest-Ray: Process LOCAL GEE Results
# Objective: Link manually downloaded CSVs to the H3 Hierarchical Grid

library(dplyr)
library(sf)
library(here)
library(readr)

root_dir <- here()
data_dir <- file.path(root_dir, "data")
rgee_dir <- file.path(root_dir, "rgee")

cat("Processing local CSV files from rgee directory...\n")

# 1. LOAD LOCAL DATA
path_res10 <- file.path(rgee_dir, "revorest_extract_res10.csv")
path_res12 <- file.path(rgee_dir, "revorest_extract_res12.csv")

if (!file.exists(path_res10) || !file.exists(path_res12)) {
  stop("File CSV tidak ditemukan di folder rgee/. Pastikan file revorest_extract_res10.csv dan res12 ada.")
}

cat("Loading Res 10 data...")
raw_10 <- read_csv(path_res10, show_col_types = FALSE)
cat(" DONE.\nLoading Res 12 data...")
raw_12 <- read_csv(path_res12, show_col_types = FALSE)
cat(" DONE.\n")

# 2. LOAD GRID STRUCTURES
grid_res10 <- readRDS(file.path(data_dir, "ray_grid_res10.rds"))
grid_res12 <- readRDS(file.path(data_dir, "ray_grid_res12.rds"))
grid_res8  <- readRDS(file.path(data_dir, "ray_grid_res8.rds"))

# 3. ENRICH RES 10 (Token Level)
cat("Enriching Token Grid (Res 10)...\n")
enriched_res10 <- grid_res10 %>%
  left_join(raw_10, by = "h3_index_res10") %>%
  mutate(
    radar_vh = VH_mean,
    radar_vh_sd = VH_stdDev,
    ndvi_mean = NDVI_mean,
    cloud_mask = ifelse(is.na(NDVI_mean), "CLOUDY", "CLEAR")
  ) %>%
  # Hapus kolom teknis GEE agar tidak duplikat saat simpan GPKG
  select(h3_index_res10, h3_index_res8, token_id, state, 
         radar_vh, radar_vh_sd, ndvi_mean, cloud_mask)

# 4. ENRICH RES 12 (Scanner Level)
cat("Enriching Scanner Grid (Res 12)...\n")
enriched_res12 <- grid_res12 %>%
  left_join(raw_12, by = "h3_index_res12") %>%
  mutate(
    radar_vh = VH,
    ndvi_mean = NDVI
  ) %>%
  # Pilih kolom esensial saja
  select(h3_index_res12, h3_index_res10, radar_vh, ndvi_mean)

# 5. AGGREGATE TO RES 8 (Landscape Level)
cat("Aggregating statistics to Landscape Grid (Res 8)...\n")
stats_res8 <- enriched_res10 %>%
  st_drop_geometry() %>%
  group_by(h3_index_res8) %>%
  summarise(
    avg_ndvi = mean(ndvi_mean, na.rm = TRUE),
    avg_radar = mean(radar_vh, na.rm = TRUE),
    cloud_cover_pct = sum(cloud_mask == "CLOUDY") / n() * 100,
    .groups = "drop"
  )

enriched_res8 <- grid_res8 %>%
  left_join(stats_res8, by = "h3_index_res8")

# 6. SAVE FINAL ENRICHED DATA
cat("Saving final enriched hierarchical datasets to /data...\n")
saveRDS(enriched_res8,  file.path(data_dir, "ray_enriched_res8.rds"))
saveRDS(enriched_res10, file.path(data_dir, "ray_enriched_res10.rds"))
saveRDS(enriched_res12, file.path(data_dir, "ray_enriched_res12.rds"))

# Save GeoPackage for GIS inspection
st_write(enriched_res8,  file.path(data_dir, "ray_enriched_res8.gpkg"),  delete_dsn = TRUE)
st_write(enriched_res10, file.path(data_dir, "ray_enriched_res10.gpkg"), delete_dsn = TRUE)
st_write(enriched_res12, file.path(data_dir, "ray_enriched_res12.gpkg"), delete_dsn = TRUE)

cat("\n=== SUCCESS: Data satelit ASLI (Lokal) telah digabungkan ===\n")
cat("Sekarang jalankan: source('02b_visualize_satellite_data.R')\n")
