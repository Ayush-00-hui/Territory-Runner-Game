# Territory Runner — UI Polish & Design System Pass

## 1. Executive Summary
The **UI Polish & Avatar Pass** (`ui-polish-avatar`) elevates Territory Runner into an athletic, high-contrast, distraction-free product adhering to strict design system tokens, WCAG AAA accessibility, and performance budgets.

Key objectives achieved:
1. **Typography & Token Integrity:** Hard-coded `fontSize` values and raw paddings removed from user-facing screens and mapped to `AppText` and `AppSpacing` tokens. Guarded by automated static tests against unbundled font weights (`w500`, `w800`, `w900`) and arbitrary font sizes.
2. **Branded Loading Experience:** 17 generic inline `CircularProgressIndicator` instances replaced with branded `InlineLoading` (powered by `_TrackLoopPainter`) and full-area `AppLoadingView` with 90 athletic facts and 10-second timeout recovery dialogs.
3. **Pure Flutter Vector Avatar:** Kinematic animated running character with a 60-item wardrobe across 6 categories, persisted locally in Hive (`avatar_v1`) without external dependencies.
4. **48 dp Minimum Targets & Extreme Accessibility:** All touch targets guaranteed $\ge 48\times 48\text{ dp}$. Verified zero layout overflow across 3 device form factors (360×640, 393×852, 412×915) at 1.0x, 1.3x, and 2.0x text scale.

---

## 2. Before / After Comparison against Phase U0 Audit

| Audit Area | Before (Phase U0 Audit) | After (Phase U1/L/A/V) | Verification Test |
| :--- | :--- | :--- | :--- |
| **Typography Tokens** | ~424 hardcoded `fontSize` declarations and unbundled `FontWeight.w500` used across sheets and cards. | Mapped to `AppText` semantic scales (`statHero`, `displayMedium`, `displaySmall`, `bodyMedium`, `caption`, `labelSmall`). Strict bundled Inter weights (`w400`, `w600`, `w700`). | `test/design_system_test.dart` |
| **Spacing & Radii** | Arbitrary EdgeInsets (`all(7)`, `symmetric(horizontal: 13)`), non-standard radii (`br14`). | Unified to `AppSpacing` tokens (`s4`, `s6`, `s8`, `s10`, `s12`, `s14`, `s16`, `s20`, `s24`) and standard radii (`br8`, `br12`, `br16`, `br24`, `brFull`). | `test/design_system_test.dart` |
| **Touch Targets** | Sub-48dp interactive elements on scope pills, callsign edit buttons, and SOS triggers. | All interactive touch bounds expanded to minimum $48\times 48\text{ dp}$ with explicit Semantics. | `test/u6_polish_and_proof_test.dart` |
| **Loading Indicators** | 17 unstyled `CircularProgressIndicator` widgets across HUDs, sheets, and dialogs. | Standardized on `InlineLoading` (TrackLoop painter) and `AppLoadingView` with 90 cross-fading athletic facts. | `test/ui/loading_experience_test.dart` |
| **Network & Loading Timeouts**| Unbounded loading spinners with no timeout or cancellation escape route. | 10-second timeout recovery dialog allowing retry or quiet cancellation. | `test/ui/loading_experience_test.dart` |
| **Banned Words & Jargon** | Gaming jargon ("telemetry", "polygon", "game", "grind", "sector"). | Clean, calm sports terminology ("tracker", "shape", "loop", "session", "run"). | `test/banned_words_audit_test.dart` |
| **Rapid Double-Tap Protection**| Unprotected primary and secondary buttons vulnerable to duplicate network triggers. | Built-in debouncer ($\Delta t < 650\text{ ms}$) on `PrimaryButton` and `SecondaryButton`. | `test/ui/button_and_interaction_test.dart` |
| **Runner Character** | Generic text initials circle in `ProfileHeroCard`. | Pure Flutter vector runner avatar with harmonic joint kinematics, standing ready pose, and 60 wardrobe items. | `test/ui/avatar_and_wardrobe_test.dart` |
| **Text Scaling** | Text truncation or RenderFlex overflows at text scales $> 1.2$. | Verified zero overflow and graceful text scaling up to 2.0x extreme scale across 3 device aspect ratios. | `test/phase_d6_accessibility_and_responsiveness_test.dart` |
| **Haptic Feedback** | Missing or non-centralized vibration triggers. | Centralized haptic events (run start, loop closed, item equip) routed through user haptic preferences. | `test/ui/avatar_and_wardrobe_test.dart` |

---

## 3. Architecture & Key Modules Added

### 3.1 Loading Experience (`lib/ui/widgets/`)
- [`inline_loading.dart`](file:///lib/ui/widgets/inline_loading.dart): Compact $16\text{ dp}$ / $20\text{ dp}$ / $24\text{ dp}$ spinner with electric blue contour and mustard pulse.
- [`app_loading_view.dart`](file:///lib/ui/widgets/app_loading_view.dart): Full-area loading view with rotating biomechanics, athletic culture, and training science facts, plus a 10s timeout dialog.
- [`lib/services/loading_quotes_service.dart`](file:///lib/services/loading_quotes_service.dart): Loads and shuffles 90 curated athletic quotes from `assets/loading_quotes.json`.

### 3.2 Runner Character & Wardrobe (`lib/models/`, `lib/services/`, `lib/ui/widgets/`)
- [`runner_avatar.dart`](file:///lib/models/runner_avatar.dart): Immutable avatar model with category item IDs and pose state.
- [`wardrobe_catalog.dart`](file:///lib/models/wardrobe_catalog.dart): 60 athletic items with unlock conditions (`free`, `level`, `distance`, `streak`).
- [`avatar_service.dart`](file:///lib/services/avatar_service.dart): Manages local Hive persistence in `avatar_v1`.
- [`runner_avatar_painter.dart`](file:///lib/ui/widgets/runner_avatar_painter.dart): Pure Flutter `CustomPainter` vector renderer with harmonic stride kinematics and reduced motion awareness.
- [`wardrobe_sheet.dart`](file:///lib/features/profile/widgets/wardrobe_sheet.dart): Bottom sheet for trying on and equipping unlocked gear.

---

## 4. Verification Evidence

### Automated Test Suite
- **Design Tokens & System:** 27 / 27 passed
- **Banned Words & Tone:** 7 / 7 passed
- **Touch Targets & Overflow (U6):** 9 / 9 passed
- **Accessibility & Responsiveness (D6):** 21 / 21 passed
- **UI & Avatar Suite:** 24 / 24 passed
- **Static Analysis (`flutter analyze`):** Clean (0 warnings, 0 errors, 0 infos)

---

## 5. Release Notes (Calm Tone)

### Version 2.2 — Visual Polish & Runner Avatar
* **Vector Runner Avatar:** Customize your running buddy with unlockable athletic gear earned by logging distance, maintaining daily streaks, and leveling up.
* **Refined Typography & Spacing:** Streamlined metrics cards, HUD, and sheets with higher contrast and clear tabular numerals.
* **Calm Loading:** Smooth track-loop indicators and athletic training insights replace generic spinners.
* **Accessibility Enhancements:** Guaranteed minimum 48 dp touch controls and responsive layouts adapting up to 2.0x text scaling.

