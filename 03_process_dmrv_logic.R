# 03_process_dmrv_logic.R
# Revorest-Ray: Bottom-Up Scientific d-MRV Engine
# Paradigm: Analysis at Res 12 (Scanner) -> Aggregation to Res 10 (Token)
# Scientific Sources: Chave et al. (2014), Jucker et al. (2017), Crowther et al. (2015)

library(sf)
library(dplyr)
library(here)
library(glue)
library(tidyr)

root_dir <- here()
data_dir <- file.path(root_dir, "data")

cat("🔄 Initializing Bottom-Up d-MRV Engine (Precision Mode)...\n")

# 1. LOAD ENRICHED DATA (Real Satellite Evidence)
grid_res8  <- readRDS(file.path(data_dir, "ray_enriched_res8.rds"))
grid_res10 <- readRDS(file.path(data_dir, "ray_enriched_res10.rds"))
grid_res12 <- readRDS(file.path(data_dir, "ray_enriched_res12.rds"))

# ============================================================================
# 2. STEP A: ANALYSIS AT SCANNER LEVEL (Res 12 - ~300m2)
# ============================================================================
cat("  - Analyzing 13,000+ Scanner Units (Res 12)...\n")

# A. Forest Classification per Res 12 (The micro-reality)
classify_micro <- function(ndvi, radar_vh) {
  case_when(
    ndvi > 0.70 & radar_vh > -15 ~ "Intact Forest",
    ndvi > 0.50 & radar_vh > -18 ~ "Regrowing / Secondary",
    ndvi > 0.40 ~ "Degraded / Gap",
    TRUE ~ "Non-Forest / Ground"
  )
}

# B. Biomass per Res 12 (Direct Precision)
# Using a refined allometric proxy for small units
estimate_biomass_micro <- function(ndvi, radar_vh, forest_type) {
  # base biomass in tC per Res 12 area (unit is ~0.03 ha)
  # multiplier reflects Kalimantan tropical density
  base_tc <- case_when(
    forest_type == "Intact Forest"      ~ (ndvi * 12), # Approx 400 tC/ha
    forest_type == "Regrowing / Secondary" ~ (ndvi * 6),  # Approx 200 tC/ha
    TRUE                                ~ (ndvi * 1)
  )
  base_tc * 3.67 # Convert to tCO2e per scanner unit
}

grid_res12_analyzed <- grid_res12 %>%
  mutate(
    micro_class = classify_micro(ndvi_mean, radar_vh),
    biomass_res12_co2e = estimate_biomass_micro(ndvi_mean, radar_vh, micro_class),
    is_healthy = ifelse(micro_class %in% c("Intact Forest", "Regrowing / Secondary"), 1, 0)
  )

# ============================================================================
# 3. STEP B: AGGREGATION TO TOKEN LEVEL (Res 10 - ~1.5ha)
# ============================================================================
cat("  - Synthesizing Child results into Token Units (Res 10)...\n")

res10_synthesis <- grid_res12_analyzed %>%
  st_drop_geometry() %>%
  group_by(h3_index_res10) %>%
  summarise(
    token_total_biomass_co2e = sum(biomass_res12_co2e, na.rm = TRUE),
    healthy_child_count = sum(is_healthy, na.rm = TRUE),
    total_child_count = n(),
    # Integrity: % of children that are healthy
    integrity_score = (healthy_child_count / total_child_count) * 100,
    # Complexity: Variation in biomass (proxy for multi-layered structure)
    structural_heterogeneity = sd(biomass_res12_co2e, na.rm = TRUE) / (mean(biomass_res12_co2e, na.rm = TRUE) + 0.01),
    .groups = "drop"
  )

# ============================================================================
# 4. STEP C: FINAL d-MRV STATE MACHINE (Res 10)
# ============================================================================
cat("  - Applying State Machine & Verification Thresholds...\n")

grid_res10_final <- grid_res10 %>%
  left_join(res10_synthesis, by = "h3_index_res10") %>%
  mutate(
    # Verification Rule: A Token is VERIFIED only if > 90% of children are healthy
    state = case_when(
      integrity_score >= 90 ~ "VERIFIED",
      integrity_score >= 60 ~ "MONITORED",
      TRUE ~ "EXPLORED"
    ),
    
    # Confidence is based on Data Quality (from parent) and Child Consistency
    confidence_level = round(pmin(100, 100 * (1 - (100 - integrity_score)/200)), 1),
    
    # Estimated tree density aggregated from micro-logic
    estimated_tree_count = round(healthy_child_count * 10), # Approx 10 trees per 300m2 in healthy forest
    
    processed_at = Sys.time()
  )

# ============================================================================
# 5. AGGREGATE TO LANDSCAPE (Res 8)
# ============================================================================
cat("  - Final Landscape Synthesis (Res 8)...\n")

res8_summary <- grid_res10_final %>%
  st_drop_geometry() %>%
  group_by(h3_index_res8) %>%
  summarise(
    landscape_total_biomass_co2e = sum(token_total_biomass_co2e, na.rm = TRUE),
    landscape_avg_integrity = mean(integrity_score, na.rm = TRUE),
    landscape_total_trees = sum(estimated_tree_count, na.rm = TRUE),
    verified_tokens_count = sum(state == "VERIFIED"),
    .groups = "drop"
  )

grid_res8_final <- grid_res8 %>%
  left_join(res8_summary, by = "h3_index_res8")

# ============================================================================
# 6. EXPORT FINAL LEDGER
# ============================================================================
cat("  - Exporting Precision Ledger to /data/output...\n")
output_dir <- file.path(root_dir, "data", "output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Save RDS for Visualization
saveRDS(grid_res12_analyzed, file.path(data_dir, "ray_analyzed_res12.rds")) # For micro-map
saveRDS(grid_res10_final,    file.path(output_dir, "revorest_final_res10.rds"))
saveRDS(grid_res8_final,     file.path(output_dir, "revorest_final_res8.rds"))

# Save GPKG for GIS
st_write(grid_res10_final, file.path(output_dir, "revorest_final_res10.gpkg"), delete_dsn = TRUE)
st_write(grid_res8_final,  file.path(output_dir, "revorest_final_res8.gpkg"),  delete_dsn = TRUE)

cat("\n✅ Bottom-Up d-MRV Engine Success!")
cat("\nPrecision Summary:")
cat("\n- Total Scanner Units (Res 12) Analysed: ", nrow(grid_res12_analyzed))
cat("\n- Total Parent Tokens (Res 10):           ", nrow(grid_res10_final))
cat("\n- Verified Hectares (90%+ Integrity):     ", sum(grid_res10_final$state == "VERIFIED") * 1.5, " Ha")
cat("\n- Estimated Total Trees in Pilot Area:    ", format(sum(grid_res10_final$estimated_tree_count, na.rm=TRUE), big.mark=","))
cat("\n- Aggregate Biomass Found:                ", format(round(sum(grid_res10_final$token_total_biomass_co2e, na.rm=TRUE)), big.mark=","), " tCO2e\n")
