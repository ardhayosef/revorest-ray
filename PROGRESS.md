# 📈 Project Progress: Revorest-Ray Pilot

Dokumentasi riwayat pembangunan pipeline d-MRV untuk wilayah IKN.

## Step 1: Hierarchical Grid Initialization
- **Goal:** Membangun struktur spasial H3 yang kompatibel dengan standar ledger.
- **Result:** Berhasil membuat hierarki 3 lapis (Res 8, 10, 12).
- **Validation:** Visualisasi Leaflet dengan fitur *Adaptive Zoom* (Z1-12: Landscape, Z13-15: Token, Z16+: Scanner).
- **Fixes:** Penyesuaian API H3 v4 (`polygon_to_cells`, `cell_to_polygon`).

## Step 2: Multi-Sensor Satellite Fetching
- **Goal:** Menarik bukti (evidence) asli dari Sentinel-1 & 2 tanpa batas fitur GEE.
- **Result:** Implementasi *Native Batch Task Export* ke Google Drive. Berhasil menarik data Radar VH dan NDVI tahun 2025-2026.
- **Validation:** Peta panas NDVI asli untuk 13.000+ scanner units di IKN.
- **Strategy:** Pemisahan "Engine" (GEE) dan "Logic" (Local R) untuk transparansi ledger.

## Step 3: Bottom-Up d-MRV Engine
- **Goal:** Mengubah data mentah menjadi klaim karbon yang sah secara ilmiah.
- **Result:** Implementasi paradigma **Bottom-Up**:
    - Analisis klasifikasi & biomassa dilakukan di level Res 12 (~300m2).
    - Status "VERIFIED" di level hektar (Res 10) ditentukan oleh kesehatan 90% sel anak.
    - Integrasi kaidah ilmiah: Chave et al. (Biomass), Jucker et al. (Architecture), dan Crowther et al. (Tree Count).
- **Validation:** Peta Ledger Akhir dengan tooltip detail per unit scanner.

---
**Current Status:** Backend Analytical Pipeline - **100% Complete**
