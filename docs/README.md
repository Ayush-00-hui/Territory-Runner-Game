# Territory Runner — Technical Documentation Index

Welcome to the comprehensive technical documentation repository for **Territory Runner**, a server-authoritative real-time location-based athletic fitness platform.

This directory contains formal engineering dossiers, mathematical proofs, threat models, database schemas, and operational runbooks.

---

## 📑 Documentation Catalog by Domain

### 1. 🏗️ Architecture, Distributed Systems & Database
- **[DEPLOYMENT.md](DEPLOYMENT.md)** — Production deployment specification: Multi-stage Docker containers, PostgreSQL 16 + PostGIS 3.4 database tuning, Fly.io edge orchestration, and Kubernetes manifests.
- **[LOCAL_SERVER.md](LOCAL_SERVER.md)** — Zero-friction local development environment setup, database migrations (`000001`–`000018`), and seed scripts.
- **[MECHANICS.md](MECHANICS.md)** — Territory polygon capture, Shoelace loop closure, 120-minute territory shields, rival theft clipping, and hourly decay mechanics.
- **[DATA_SOURCE_AUDIT.md](DATA_SOURCE_AUDIT.md)** — Data model audit, level calculation formulas, XP progression curves, and server contract specifications.
- **[ERROR_CODES.md](ERROR_CODES.md)** — Canonical REST and WebSocket error codes, HTTP status mappings, and retry policies.

### 2. 🛡️ Security, Privacy & Compliance
- **[THREAT_MODEL.md](THREAT_MODEL.md)** — Formal STRIDE security analysis covering Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, and Elevation of Privilege.
- **[PRIVACY.md](PRIVACY.md)** — Athlete privacy zones, geofence radius masking, coordinate obfuscation, and zero-knowledge location export (GPX/GeoJSON).
- **[STORE_READINESS.md](STORE_READINESS.md)** — Google Play & Apple App Store compliance: Android 14 `FOREGROUND_SERVICE_LOCATION` permissions (`targetSdk 36`), iOS Background Modes (`remote-notification`, `location`), and Privacy Manifests.

### 3. 🤖 AI, Machine Learning & Anti-Cheat
- **[AIML_EVALUATION.md](AIML_EVALUATION.md)** — Evaluation dossier for the 25-feature LightGBM anti-cheat ensemble: ROC/PR curves, kinematic physics bounds, leave-one-user-out (LOUO) validation, and ONNX deployment.
- **[ACTIVITY_FAIRNESS.md](ACTIVITY_FAIRNESS.md)** — Biomechanical cadence constraints, speed envelopes, and MET energy expenditure formulas across Running, Walking, and Cycling.
- **[CALORIES.md](CALORIES.md)** — Dual-mode calorie expenditure engine: Minetti-Pugnaloni incline physics equations and gradient-boosted regression trees.

### 4. 🎨 Design System, Motion & Accessibility
- **[UX_CHECKLIST.md](UX_CHECKLIST.md)** — High-contrast Obsidian & Calm Moss design system, WCAG AAA automated contrast verification, and tabular athletic typography.
- **[UI_POLISH.md](UI_POLISH.md)** — Design tokens, 48dp minimum touch targets, responsive small-viewport sheets (320px/360px), and sports terminology guidelines.
- **[ASSETS.md](ASSETS.md)** — Asset manifest, audio files, Inter font weights, and LightGBM model weights with SHA-256 integrity hashes.
- **[AVATAR.md](AVATAR.md)** — Procedural vector runner avatar stance painting, wardrobe customization, and athletic visual progression.

### 5. 🧪 Testing, Quality & Operations
- **[VERIFICATION.md](VERIFICATION.md)** — Master verification dossier documenting all 743 Flutter client tests, 11 Go backend packages, PostGIS integration test flows, and golden fixture parity.
- **[REVIEW_FINDINGS.md](REVIEW_FINDINGS.md)** — Comprehensive audit findings log and resolved bugs across client, backend, database, and telemetry pipelines.
- **[IMPROVEMENT_REPORT.md](IMPROVEMENT_REPORT.md)** — Audit report and remediation milestones.
- **[REAL_PHONE_QA_CHECKLIST.md](REAL_PHONE_QA_CHECKLIST.md)** — Real physical device testing procedures across Android and iOS hardware.

### 6. 🎓 Examination & College Defense Suite
- **[VIVA.md](VIVA.md)** — Master viva defense cheatsheet answering 50+ tough technical questions on concurrency, PostGIS spatial queries, advisory locks, and anticheat ML.
- **[STUDY_NOTES.md](STUDY_NOTES.md)** — Comprehensive 8-module textbook covering all system layers.
- **[presentation/](presentation/)** — Individual college defense scripts, slide decks, and presentation materials.
- **[artifacts/](artifacts/)** — Compiled documentation artifacts, printable study notes, and generated PDF handbooks.
