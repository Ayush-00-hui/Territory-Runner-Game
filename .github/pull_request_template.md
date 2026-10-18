## Summary of Changes
<!-- Provide a concise description of the motivation and changes in this pull request. -->

---

## Architectural Impact
- [ ] Flutter UI & Design System (`lib/ui/`, `lib/features/**/widgets`)
- [ ] State Management & Telemetry (`lib/features/gameplay/`, `ValueNotifier`)
- [ ] Background GPS Lifecycle (`lib/services/location_service.dart`)
- [ ] Spatial Engine & Kinematics (`lib/features/gameplay/` / `backend/internal/geo/`)
- [ ] Go API & Handlers (`backend/internal/api/`)
- [ ] PostgreSQL / PostGIS Store (`backend/internal/store/`, migrations)
- [ ] CI/CD & DevOps (`.github/workflows/`, Docker)

---

## Parity & Kinematic Safety Checklist
- [ ] **Dual-Engine Parity**: If spatial, enclosure, or outlier logic was modified, changes are mirrored in both Dart (`polygon_enclosure_engine.dart`) and Go (`geo/engine.go`).
- [ ] **Golden Fixtures**: Evaluated against test fixtures in `test_fixtures/` (walking, running, cycling).
- [ ] **Database Migration**: Forward (`.up.sql`) and backward (`.down.sql`) migrations included if schema changed.
- [ ] **Anti-Cheat Integrity**: Consecutive sample speed calculations and temporal hygiene preserved.

---

## Local Verification Evidence
- [ ] `flutter analyze`: `No issues found!`
- [ ] `flutter test`: All tests passing
- [ ] `go vet ./...`: No issues found
- [ ] `go test -count=1 ./...`: All packages passing

```bash
# Paste verification outputs here:
```

---

## Viva Defense Rationale
<!-- Provide a 2-3 line engineering defense for any non-trivial design or mathematical decisions. -->
