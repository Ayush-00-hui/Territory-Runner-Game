# 🏃‍♂️ Territory Runner (AI-Powered Fitness Conquest)

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.13+-02569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.0+-0175C2.svg?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/H3_Geospatial-Resolution_10-orange.svg?style=for-the-badge" alt="H3 Indexing" />
  <img src="https://img.shields.io/badge/Google_Gemini-LLM_Coach-blueviolet.svg?style=for-the-badge" alt="Gemini" />
  <img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License" />
</div>

<br>

**Territory Runner** is a location-based fitness and territory conquest app built with Flutter. Sweat it out in the real world to claim real-world hexagonal territory on an interactive cyber-themed live map.

---

## ✨ Implemented Features

### 📍 1. Real-Time H3 Hexagonal Conquest (`lib/features/gameplay/`)
- **H3 Geospatial Indexing:** Uses H3 Resolution 10 (~65.9m edge length, ~15,047 m² area, ~131.8m diameter), perfectly scaled for urban running and walking blocks.
- **Dynamic Hex Capture:** Computes geodesic 6-vertex boundaries, calculates area in square meters, and awards **+10 XP** per conquered sector.
- **Hive Typed Persistence:** Offline-first caching with custom Hive `TypeAdapter<Territory>` and `TypeAdapter<RunnerProfile>`.

### 🧭 2. AI Route Recommendation Engine (`lib/features/routing/`)
- **Orienteering Problem Formulation:** Solves the loop route synthesis problem on the H3 hex graph (maximizing unclaimed hex prizes within target distance budget).
- **Two-Phase Optimization:**
  1. *Greedy baseline* loop construction with start/return constraints.
  2. *2-Opt local search* and greedy node insertion under a 400ms on-device budget.
- **Map Overlay:** One-tap "Suggest AI Route" button with glowing polyline overlay on `MapScreen`.

### 🛡️ 3. Anti-Cheat & GPS Anomaly Detection (`lib/features/security/`)
- **Telemetry Feature Extraction:** Real-time sliding window analysis of instant speed, max acceleration ($\Delta v / \Delta t$), heading change rate, path sinuosity, and stop frequency.
- **Multi-Tier Detection:**
  - Fast rule-based hard filters (`isMocked == true`, instant speed > 25 km/h, teleport jumps > 50m in < 1s).
  - Statistical weighted Z-Score/Mahalanobis anomaly scoring model trained offline (`scripts/train_anomaly_model.py`).
- **Non-blocking Flagging:** Suspicious captures are flagged as `isPendingReview: true` without interrupting the run.

### 🤖 4. Gemini AI Post-Run Coach (`lib/features/coach/`)
- **Post-Run Telemetry Digest:** Feeds distance, duration, average pace splits, newly claimed sectors, level, and streaks into `google_generative_ai` (Gemini 1.5 Flash).
- **Strict Schema Parsing:** Returns structured `{ summary, tip, moodTag }` with retry recovery and offline fallback.
- **Interactive Conquest Summary:** Dark cyber-athletic post-run modal with stats breakdowns and tactical tips.

### 📈 5. Adaptive Pace & Distance Prediction (`lib/features/coach/`)
- Fits athletic decay and progression curves to user level, historical distance, and streaks to predict achievable target distances and pacing.
- Seamlessly feeds predicted distances into the AI Route Recommendation Engine.

### ☁️ 6. Cloud Sync & Firebase Auth (`lib/services/`)
- **Firebase Auth:** Supports Email/Password and Anonymous single-tap authentication.
- **Cloud Firestore:** Real-time territory and profile synchronization with a *server-timestamp-wins* conflict resolution rule for contested territories.

---

## 🗺️ Roadmap (Future Scope)

- [ ] **Reinforcement Learning (RL) Rival Agents:** AI runners that simulate opposing factions contesting player hexes.
- [ ] **RAG-based Coaching & Voice Cues:** Real-time audio commentary and contextual hydration/nutrition retrieval during active runs.
- [ ] **Local Multiplayer Guild Battles:** Team-based polygon territory mergers and faction turf wars.

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) & Dart 3
- **Geospatial & Maps:** `flutter_map`, `latlong2`, `geolocator`, H3 Geodesic Indexing
- **AI & ML:** `google_generative_ai` (Gemini), Scikit-Learn Anomaly Classifier
- **Local Storage:** `hive_flutter` with custom TypeAdapters
- **Cloud & Auth:** Firebase Core, Firebase Auth, Cloud Firestore

---

## 🚀 Getting Started

### 1. Clone and Install
```bash
git clone https://github.com/Ayush-00-hui/Territory-Runner-Game.git
cd Territory-Runner-Game
flutter pub get
```

### 2. Configure Environment (Optional for Gemini AI)
Pass your Gemini API key when launching the app:
```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

### 3. Run Tests & Benchmarks
```bash
flutter test
```

---

## 📄 License
Licensed under the [MIT License](LICENSE).
