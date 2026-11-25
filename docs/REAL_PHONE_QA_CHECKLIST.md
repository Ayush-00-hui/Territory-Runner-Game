# Real-Phone QA Verification Checklist

This field-testing checklist validates **Territory Runner** on physical iOS and Android hardware under real outdoor conditions. It covers sensor anomalies, hardware constraints, ambient sunlight, accessibility, and multiplayer edge cases.

---

## 📋 Field Verification Matrix

| # | Test Scenario | Real-World Condition | Expected Behavior | Failure Indicators |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Tree Canopy & Urban Canyons** | Running under dense tree cover or between 8+ story high-rises. Horizontal accuracy degrades from $\pm 5\text{m}$ to $\pm 18\text{–}30\text{m}$. | Dynamic loop closure threshold expands smoothly from $33\text{m}$ up to $42\text{m}$ based on $R_{eff} = \text{clamp}(25, 50, 35 + (\sigma - 10) \times 0.4)$. GPS Kalman filter prevents jitter. Loop closes cleanly. | Loop fails to close when crossing within 35m of path; erratic zig-zag paths; phantom "Loop too large" rejection. |
| **2** | **Walking vs. Running Transitions** | Start with a brisk walk ($4.5\text{ km/h}$, $110\text{ SPM}$), transition into a run ($11\text{ km/h}$, $165\text{ SPM}$), then stop at a red light. | ZUPT stationary filter immediately freezes distance accumulation on stop ($0.0\text{ m}$ drift). Auto-pause arms after crossing $2.5\text{ km/h}$ and triggers upon stopping. Cadence transitions cleanly without vehicle warnings. | Distance increments while waiting at traffic lights; auto-pause false triggers mid-stride; speed spike rejection on acceleration. |
| **3** | **Screen-Off Background Running** | Lock the phone display mid-run. Run for 1.5 km with phone in pocket or armband, then unlock. | Android Foreground Service notification updates distance and time in real-time. CPU WakeLock maintains GPS fix pipeline without gaps. Zero missing coordinates upon unlock. | Flat-line jump between lock and unlock coordinates; workout terminated by Android Doze; distance stops counting. |
| **4** | **Low Battery Endurance Mode (15%)** | Start run with battery below 15% or discharge during run. | App prompts athlete with Endurance Battery Saver dialog. AMOLED HUD renders pure `#000000` obsidian display with high-contrast essential metrics. CPU throttles animations and GPS sampling to 3s interval. | Phone dies before completing workout; screen draws full GPU power; crash on battery broadcast. |
| **5** | **Offline Airplane Mode & Reconnect** | Toggle Airplane Mode mid-run. Complete a loop, finish workout, then disable Airplane Mode. | Loop enclosure preview displays optimistically via local Clipper2 engine. Run enqueues into encrypted Hive FIFO sync queue (`syncStatus: offline`). When network restores, background sync uploads run with exponential backoff and reconciles with PostGIS. | Infinite spinner; lost workout; data loss on app kill before reconnect; crash when `SocketException` occurs. |
| **6** | **Permission Denied Mid-Run** | Revoke Location permission in OS App Settings while run is active, then return to app. | App surfaces calm amber notice (`Waiting for GPS`) without throwing unhandled exception. Accumulated path coordinates and elapsed time remain intact. Granting permission resumes tracking seamlessly. | Red screen crash; unhandled `PlatformException`; track erased or reset to 0 km. |
| **7** | **Demo Mode Isolation** | Toggle Demo Mode ON in Map Tools Sheet. Run a virtual pacer route. Toggle Demo Mode OFF. | Simulated run HUD renders calm `SIMULATED (DEMO)` badge. Local history records run with `Demo run` tag. Backend strictly rejects any submission attempt (`SIMULATED_RUN_REJECTED`). Total XP and leaderboard area remain untouched. | Simulated runs awarding real XP; fake runs polluting public leaderboard; demo mode remaining enabled silently. |
| **8** | **High-Contrast Sunlight Readability** | Open app in direct overhead midday sunlight in Light Theme. | Deep Pine (`#2D4224`), Athletic Charcoal (`#0E1116`), and High-Contrast Accent Ochre (`#8C6D1F`) provide WCAG AA contrast ratio $\ge 4.5:1$. Tabular figures remain readable at arm's length without eye strain. | Washed out text; unreadable pace timers; invisible territory boundaries on map. |
| **9** | **200% Font Scale Accessibility** | Set device system font size to Largest / 2.0x text scale. Walk through Map, History, Leaderboard, and Profile. | All metrics, bottom navigation items, cards, and modal sheets wrap or scroll cleanly without RenderFlex overflows or text truncation. | RenderFlex yellow-and-black striped overflow banners; truncated buttons; unclickable buttons. |
| **10** | **Left-Handed Thumb Zone Ergonomics** | Toggle Left-Handed Mode in Settings. Hold phone single-handed with left hand. | MapControlsRail, primary action pills, and sheet dismiss buttons mirror to the left thumb sweep zone ($\le 60\text{mm}$ reach from bottom-left corner). Touch targets maintain $\ge 48\times 48\text{ dp}$. | Buttons requiring uncomfortable two-handed grip; touch targets under 48 dp. |
| **11** | **3x Identical Loop Net Area Test** | Run the exact same 400m track loop 3 times in one workout session. | **Run 1**: Encloses loop, awards full net area (e.g. $12,500\text{ m}^2$) and proportional XP.  <br>**Run 2**: Re-running inside existing territory yields $\text{NetNewArea} = 0.0\text{ m}^2$, $0\text{ XP}$. <br>**Run 3**: Third loop yields $\text{NetNewArea} = 0.0\text{ m}^2$, $0\text{ XP}$. Total owned land in profile equals $12,500\text{ m}^2$, not $37,500\text{ m}^2$. | Double or triple area credit; farming XP by repeating the same loop; server and client area mismatch. |
| **12** | **Capturing Next to Shielded Rival** | Run a loop that overlaps a rival territory with an active 120-minute sovereign defense shield (`cooldown_until > NOW()`). | Shielded rival ground is clipped out *prior to union* via `ST_Difference`. Only unshielded land is captured. The rival's territory remains intact with 100% geometry and ownership. Zero overlapping ownership exists. | Slicing or damaging shielded rival territory; duplicate overlapping ownership; crash on geometry difference. |

---

## 📱 Hardware Device Profiles Tested

- **Device 1**: Pixel 8 / Pixel 7 (Android 14 / 15, Target SDK 36, GNSS Dual-Frequency L1+L5)
- **Device 2**: Samsung Galaxy S22 / S23 (OneUI 6, Exynos / Snapdragon, Strict Background Battery Management)
- **Device 3**: Budget Device (Redmi Note / Galaxy A-series, 4GB RAM, Single-Frequency GNSS, High GPS Jitter)
- **Device 4**: iPhone 13 / 14 / 15 (iOS 17 / 18, Strict CoreLocation background throttle)

---

## ✅ Sign-Off Criteria for Release

1. **Zero Data Loss**: 100% of runs survive app restart, airplane mode, and battery exhaustion.
2. **Zero Invariant Violations**: Two users never hold the same ground; duplicate runs yield 0 net new area.
3. **Zero UI Overflows**: 0 RenderFlex errors across 360x640 to 412x915 viewports at 2.0x text scaling.
4. **Zero Battery Drain Spikes**: Less than 8% battery consumption per 60 minutes of active GPS tracking in AMOLED Saver mode.
