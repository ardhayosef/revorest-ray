# 🗺️ Roadmap: Revorest-Ray Visual Interface

Target selanjutnya adalah membangun antarmuka dashboard yang mampu menangani data spasial masif dengan performa tinggi.

## 1. Tech Stack (The Performance Engine)
- **Frontend Framework:** `Next.js` (React) - Untuk reaktivitas dan SSR.
- **Spatial Engine:** `Deck.gl` + `MapLibre GL` - Untuk rendering jutaan hexagon dengan GPU acceleration.
- **Backend API:** `Go` (Golang) - Sebagai high-perf spatial proxy untuk melayani data H3 dari database ke frontend dalam format GeoBuffer/Protocol Buffers.

## 2. Visual Representation (The Virtual World)
- **Isomorphic Tree Illustrations:** 
    - Alih-alih hanya warna datar, setiap hexagon Res 12 akan menampilkan objek 3D/Isometrik pohon.
    - **Visual Mapping:** Tinggi pohon dan kerapatan ilustrasi pohon di dalam hexagon akan mencerminkan nilai `biomass_tco2e` dan `estimated_tree_count`.
    - **Tilt & Perspective:** Menggunakan kemampuan `Deck.gl` untuk memberikan sudut kemiringan (tilt) 45 derajat agar hutan virtual terlihat hidup.

## 3. Interaction & d-MRV Transparency
- **Deep-Dive Navigation:** User bisa melakukan drill-down dari Landscape (Res 8) -> Token (Res 10) -> Scanner (Res 12).
- **Evidence Panel:** Klik pada hexagon untuk menampilkan grafik "Evidence History" (Sentinel data history) yang ditarik langsung dari Ledger.
- **Verification Overlay:** Fitur toggle untuk melihat "Gap Detection" (area mana saja di dalam token yang bermasalah secara mikro).

---
**Next Milestone:** Prototyping Deck.gl dengan data RDS hasil Step 3.
