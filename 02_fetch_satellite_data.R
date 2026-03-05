# 02_fetch_satellite_data.R
# Revorest MVP: IKN Pilot
# Objective: Robust REAL Sentinel Extraction (Handling heavy cloud cover in IKN)

library(sf)
library(dplyr)
library(rgee)
library(here)
library(reticulate)

root_dir <- here()
data_dir <- file.path(root_dir, "data")

# 1. DIRECT INITIALIZATION
cat("Connecting to Google Earth Engine...\n")
use_python("~/miniconda3/envs/rgee-py/bin/python", required = TRUE)
ee_py <- import("ee")
ee_py$Initialize(project = "revorest-eye-ardha")

# Load the H3 Grids
grid_res8  <- readRDS(file.path(data_dir, "ray_grid_res8.rds"))
grid_res10 <- readRDS(file.path(data_dir, "ray_grid_res10.rds"))
grid_res12 <- readRDS(file.path(data_dir, "ray_grid_res12.rds"))

cat("Menyiapkan data Sentinel (Strategy: Robust Cloud Handling)...\n")

# Rentang tanggal diperlebar (Seluruh 2025 - 2026) agar pasti dapat gambar jernih
date_start <- "2025-01-01"
date_end   <- "2026-03-05"

# AOI
aoi_geom <- sf_as_ee(st_bbox(grid_res8) %>% st_as_sfc())

# --- Sentinel-1 (Radar: Pasti berhasil karena tembus awan) ---
s1_img <- ee_py$ImageCollection("COPERNICUS/S1_GRD")$
  filterBounds(aoi_geom)$
  filterDate(date_start, date_end)$
  filter(ee_py$Filter$listContains("transmitterReceiverPolarisation", "VH"))$
  median()$ # Gunakan median agar lebih stabil
  select("VH")

# --- Sentinel-2 (Optical: Dilonggarkan agar tidak kosong) ---
s2_img <- ee_py$ImageCollection("COPERNICUS/S2_SR_HARMONIZED")$
  filterBounds(aoi_geom)$
  filterDate(date_start, date_end)$
  filter(ee_py$Filter$lt("CLOUDY_PIXEL_PERCENTAGE", 60))$ # Longgarkan filter awan
  median()

# Hitung NDVI (Gunakan try-catch GEE jika perlu, tapi kita asumsikan median 1 tahun ada datanya)
ndvi_img <- s2_img$normalizedDifference(c("B8", "B4"))$rename("NDVI")

# Gabungkan. Jika NDVI kosong, Radar tetap ada.
combined_img <- s1_img$addBands(ndvi_img)

# 2. NATIVE EXTRACTION
cat("Memulai Task Ekstraksi (Batch Mode)...\n")

res10_fc <- sf_as_ee(grid_res10 %>% select(h3_index_res10))
res12_fc <- sf_as_ee(grid_res12 %>% select(h3_index_res12))

# Ekstraksi Res 10
task_res10 <- ee_py$batch$Export$table$toDrive(
  collection = combined_img$reduceRegions(
    collection = res10_fc,
    reducer = ee_py$Reducer$mean()$combine(ee_py$Reducer$stdDev(), NULL, TRUE),
    scale = 10
  ),
  description = "revorest_extract_res10",
  fileFormat = "CSV"
)

# Ekstraksi Res 12
task_res12 <- ee_py$batch$Export$table$toDrive(
  collection = combined_img$reduceRegions(
    collection = res12_fc,
    reducer = ee_py$Reducer$mean(),
    scale = 10
  ),
  description = "revorest_extract_res12",
  fileFormat = "CSV"
)

# Jalankan Task
cat("Mengirim ulang tugas dengan filter awan lebih longgar...\n")
task_res10$start()
task_res12$start()

cat("\n=== TUGAS DIKIRIM ULANG ===\n")
cat("Silakan pantau lagi di tab 'Tasks' di web GEE.\n")
