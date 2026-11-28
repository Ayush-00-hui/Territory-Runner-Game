# Territory Runner — Automated Test Suites

This directory contains the automated test suites for the Territory Runner Flutter client, covering 743 passing unit, widget, responsive layout, golden fixture, and integration tests.

---

## 🧪 Test Execution Commands

```bash
# 1. Run all 743 unit, widget, and golden tests
flutter test

# 2. Run tests with coverage output
flutter test --coverage --timeout 120s

# 3. Run specific test categories
flutter test test/theme/          # Design system & WCAG AAA contrast
flutter test test/gameplay/       # Spatial polygon enclosure & territory decay
flutter test test/gps/            # Adaptive GPS filtering & gap tolerance
flutter test test/motion/         # Micro-interactions, haptics, animation curves
flutter test test/benchmarks/     # Performance and frame-budget benchmarks

# 4. Run end-to-end offline sync integration test
flutter test integration_test/run_flow_sync_integration_test.dart
```

---

## 📂 Test Organization

| Subdirectory / Suite | Purpose |
| :--- | :--- |
| **`test/theme/`** | Validates WCAG AAA contrast compliance, zero raw hardcoded hex colors, and dark-theme tokens. |
| **`test/gameplay/`** | Tests closed-loop Shoelace formulas, Clipper2 intersection, 120-minute shields, and decay math. |
| **`test/gps/`** | Validates Kalman distance smoothing, speed ceiling constraints, and GPS satellite jitter filters. |
| **`test/motion/`** | Tests animation curves, reduced-motion accessibility toggles, and tactile haptic policies. |
| **`test/integrity/`** | Validates anti-cheat kinematic checks, banned word filters, and client-server XP parity. |
| **`test/benchmarks/`** | Measures sub-50ms route generation and start-run frame budgets. |
| **`test/services/`** | Validates Hive local persistence, AES-256 encryption recovery, and offline sync queue deduplication. |
| **`test/social/`** | Validates crew challenges, head-to-head duels, and WebSocket real-time presence subscriptions. |
| **`test/*.dart`** | Comprehensive end-to-end user journeys (auth, run recording, HUD stats, victory summaries). |
