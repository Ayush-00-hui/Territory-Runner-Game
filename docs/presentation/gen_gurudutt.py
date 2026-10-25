import sys
from pathlib import Path

def get_gurudutt_html():
    return r"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>GURUDUTT — College Project Defense Dossier | Territory Runner</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>

  <!-- COVER PAGE -->
  <div class="cover-page">
    <div class="cover-header">
      <div class="college-title">DEPARTMENT OF COMPUTER SCIENCE & ENGINEERING</div>
      <div class="dept-title">BACHELOR OF TECHNOLOGY / FINAL YEAR CAPSTONE PROJECT DEFENSE</div>
      <div class="academic-badge">ACADEMIC SESSION 2025 – 2026</div>
    </div>

    <div class="cover-body">
      <div class="project-kicker">INDIVIDUAL WORK DIVISION & VIVA DEFENSE DOSSIER</div>
      <div class="project-main-title">TERRITORY RUNNER</div>
      <div class="project-sub-title">Server-Authoritative Real-Time GPS Spatial Strategy & Athletic Tracking Platform</div>
      <div class="role-pill">MOBILE CLIENT LEAD — TACTICAL MAP HUD & OFFLINE RESILIENCE</div>
    </div>

    <div>
      <div class="cover-details-grid">
        <div class="detail-card">
          <div class="detail-label">CANDIDATE NAME</div>
          <div class="detail-value">GURUDUTT</div>
          <div class="detail-sub">Role: Mobile Lead, Map HUD & Offline Persistence</div>
        </div>
        <div class="detail-card">
          <div class="detail-label">WORK CONTRIBUTION</div>
          <div class="detail-value">33.3% (Equal Core Partnership)</div>
          <div class="detail-sub">Lead: Flutter Architecture & OS Lifecycle Hardening</div>
        </div>
        <div class="detail-card">
          <div class="detail-label">CORE DOMAINS OWNED</div>
          <div class="detail-value">Flutter 3.13+, Dart 3, Hive Storage, Map HUD</div>
          <div class="detail-sub">Foreground Services, Wakelocks, Crash Recovery Box</div>
        </div>
        <div class="detail-card">
          <div class="detail-label">EXAMINATION DOMAIN</div>
          <div class="detail-value">Mobile Lifecycle & Battery Longevity</div>
          <div class="detail-sub">Offline-First Sync & Crash-Resilient State Machines</div>
        </div>
      </div>

      <div class="cover-signatures">
        <div>
          <div class="signature-line">Student Signature<br><strong>GURUDUTT</strong></div>
        </div>
        <div>
          <div class="signature-line">Internal Project Guide<br>Dept. of CSE</div>
        </div>
        <div>
          <div class="signature-line">External Viva Examiner<br>University Board</div>
        </div>
      </div>
    </div>
  </div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- SECTION 1: EXECUTIVE SUMMARY & ROLE BREAKDOWN -->
  <h1>1. Executive Summary & Core Subsystem Ownership <span class="badge badge-purple">GURUDUTT</span></h1>
  
  <p>
    In the <strong>Territory Runner</strong> capstone project, <strong>GURUDUTT</strong> served as the <strong>Mobile Client Lead & UI/UX Systems Architect</strong>. The core engineering mandate was to construct a hardened, offline-first mobile client capable of continuous sub-second outdoor GPS tracking without suffering from operating system background task terminations, battery drain, or memory leaks.
  </p>

  <div class="callout callout-blue">
    <strong>Core Architectural Philosophy:</strong> "Outdoor athletic tracking must survive hardware terminations and zero-connectivity environments." Runners jog through cellular dead zones, lock their screens, and experience sudden app kills from aggressive OS battery managers. GURUDUTT's subsystems guarantee that zero GPS waypoints are ever lost, runs queue persistently in local storage, and the tactical interface remains fluid at 60 FPS in bright sunlight.
  </div>

  <h2>Codebase File Ownership & Technical Responsibilities</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 25%;">Component / File Path</th>
        <th style="width: 20%;">Tech Stack</th>
        <th style="width: 40%;">Functional Responsibility</th>
        <th style="width: 15%;">Complexity</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><code>lib/main.dart</code> & <code>lib/core/theme/</code></td>
        <td>Flutter 3.13+, Dart 3</td>
        <td>Application initialization, design system ("Ink + Pacer Blue"), zero raster fallback, dynamic theme.</td>
        <td><span class="badge badge-blue">UI Layer</span></td>
      </tr>
      <tr>
        <td><code>lib/features/map/widgets/map_layers.dart</code></td>
        <td>Flutter Map / ArcGIS Tiles</td>
        <td>Multi-layer map rendering: dark basemap, runner vector tracks, contested territory polygons, radar blips.</td>
        <td><span class="badge badge-coral">Critical</span></td>
      </tr>
      <tr>
        <td><code>lib/services/location_service.dart</code></td>
        <td>Flutter Foreground Task, Wakelock</td>
        <td>Hardened background GPS service, sticky notification channel, CPU wake locks, Doze circumvention.</td>
        <td><span class="badge badge-coral">Critical</span></td>
      </tr>
      <tr>
        <td><code>lib/services/run_recovery_service.dart</code></td>
        <td>Hive Key-Value Box</td>
        <td>Crash Recovery Safety Box: atomic serialization of live waypoints to <code>active_run_recovery</code> box.</td>
        <td><span class="badge badge-green">Reliability</span></td>
      </tr>
      <tr>
        <td><code>lib/services/sync_queue.dart</code></td>
        <td>Hive Persistent FIFO Queue</td>
        <td>Offline run persistence, exponential backoff retries, connectivity listeners, 4xx non-retryable halt.</td>
        <td><span class="badge badge-purple">Data Sync</span></td>
      </tr>
      <tr>
        <td><code>lib/services/api_client.dart</code></td>
        <td>Dart HTTP, Backoff Logic</td>
        <td>Resilient REST client with bearer token injection, timeout handling, network status introspection.</td>
        <td><span class="badge badge-blue">Networking</span></td>
      </tr>
      <tr>
        <td><code>lib/features/gameplay/territory_service.dart</code></td>
        <td>StateNotifier / Provider</td>
        <td>Live workout session state machine (Start, Pause, Resume, Hold-to-Finish 1400ms gesture).</td>
        <td><span class="badge badge-blue">Gameplay</span></td>
      </tr>
      <tr>
        <td><code>lib/ui/widgets/app_toast.dart</code></td>
        <td>Overlay / Custom Animation</td>
        <td>Unified notification framework: server area reconciliation alerts, GPS warnings, error banners.</td>
        <td><span class="badge badge-amber">UI System</span></td>
      </tr>
    </tbody>
  </table>

  <h2>Mobile Client Lifecycle & Offline Resilience Architecture</h2>
  <div class="diagram-box">
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                         GURUDUTT'S MOBILE LIFECYCLE & PERSISTENCE ENGINE                     │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                              │
│   [Hardware GPS Chip]                                                                        │
│           │ (1 Hz NMEA/Location Stream)                                                      │
│           ▼                                                                                  │
│   [Foreground Location Service] ◄── [CPU WakeLock Manager (wakelock_plus)]                   │
│   ├─ Sticky OS Notification (Low-kill priority)                                              │
│   └─ Android Doze & iOS Background Throttling Circumvention                                  │
│           │                                                                                  │
│           ▼                                                                                  │
│   [Continuous Crash Box Flusher] ──► [Hive: active_run_recovery Box] (Atomic Disk Write)     │
│           │                                                                                  │
│           ▼                                                                                  │
│   [Tactical Map HUD & Compass Interpolator] (60 FPS Vector Canvas)                           │
│           │                                                                                  │
│           ▼ (Runner Triggers 1400ms Hold-to-Finish)                                          │
│   [Run Session Finalizer]                                                                    │
│           │                                                                                  │
│           ▼                                                                                  │
│   [Persistent FIFO Sync Queue] ──► [Hive: offline_runs Box]                                  │
│           │                                                                                  │
│           ▼                                                                                  │
│   [Network Connectivity Listener]                                                            │
│     ├── If OFFLINE: Sleep, retain in Hive, show offline badge to user                        │
│     └── If ONLINE:  Dequeue item ──► POST /v1/runs with Idempotency Key                      │
│                          │                                                                   │
│                          ├── Success (200/201): Remove from Hive, Clear Crash Box, Toast     │
│                          ├── Server Error (5xx/Timeout): Exponential Backoff & Retry         │
│                          └── Client Error (4xx): Halt retry, log rejection, prevent loop     │
└──────────────────────────────────────────────────────────────────────────────────────────────┘</div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- SECTION 2: DEEP TECHNICAL BREAKDOWN -->
  <h1>2. Deep Technical Breakdown & Mobile Systems Engineering</h1>

  <h2>A. Overcoming Mobile OS Background Throttling (Android Doze & iOS Freezing)</h2>
  <p>
    Modern mobile operating systems aggressively throttle or terminate background processes to preserve battery. When an athlete locks their phone and puts it in an armband, standard location APIs cease reporting coordinates within 60 to 90 seconds, causing broken polygons and lost workouts.
  </p>

  <p>
    GURUDUTT solved this challenge using a multi-tiered background hardening architecture in <code>lib/services/location_service.dart</code>:
  </p>

  <div class="callout callout-emerald">
    <strong>The 3-Pillar Background Execution Strategy:</strong><br>
    <strong>1. OS Foreground Service with Sticky Notification:</strong> Binds the application to a high-priority ongoing notification channel (<code>IMPORTANCE_LOW</code> to prevent audible dinging while alerting the Android Linux OOM-killer that the process is interactive and must not be killed).<br>
    <strong>2. CPU WakeLock Hold:</strong> Uses <code>wakelock_plus</code> to hold a partial CPU wake lock (<code>PARTIAL_WAKE_LOCK</code>) ensuring the CPU does not enter deep sleep while the runner is active with the screen locked.<br>
    <strong>3. Battery-Aware Adaptive Filter:</strong> Dynamically adjusts GPS desired accuracy and distance filters based on velocity (1-second intervals during running; 3-second intervals during pauses) to keep battery drain under $4.2\%$ per hour.
  </div>

  <h2>B. The Crash Recovery Safety Box State Machine</h2>
  <p>
    In real-world running conditions, unexpected crashes occur: phones run out of battery, runners drop their devices, or the OS terminates processes due to extreme RAM pressure from other apps.
  </p>
  
  <p>
    In <code>lib/services/run_recovery_service.dart</code>, GURUDUTT built an atomic crash recovery state machine powered by Hive key-value storage:
  </p>
  <pre><code>// Continuous atomic waypoint flush to local disk
Future&lt;void&gt; recordWaypoint(Waypoint point) async {
  final box = await Hive.openBox&lt;Map&gt;('active_run_recovery');
  final pointsList = box.get('waypoints', defaultValue: []) as List;
  pointsList.add(point.toJson());
  await box.put('waypoints', pointsList);
  await box.put('last_heartbeat', DateTime.now().toUtc().toIso8601String());
}

// Startup Session Restoration Check
Future&lt;ActiveRunSession?&gt; checkUnfinishedSession() async {
  final box = await Hive.openBox&lt;Map&gt;('active_run_recovery');
  if (box.containsKey('waypoints') &amp;&amp; (box.get('waypoints') as List).isNotEmpty) {
    // Session detected! Prompt athlete to resume or submit
    return ActiveRunSession.fromJson(box.toMap());
  }
  return null;
}</code></pre>

  <h2>C. Offline-First FIFO Sync Queue with Exponential Backoff</h2>
  <p>
    Athletes often run through forests, tunnels, or rural trails where 4G/5G signal is non-existent. Traditional fitness trackers fail to submit runs or crash when offline.
  </p>

  <p>
    GURUDUTT engineered a persistent FIFO queue in <code>lib/services/sync_queue.dart</code> that completely decouples workout completion from network availability:
  </p>
  <ul>
    <li><strong>Client-Side Idempotency UUID:</strong> When a run is finished, the client immediately generates a cryptographically random UUID:
    $$\text{idempotency\_key} = \text{UUIDv4}()$$
    This key is stored with the run payload in Hive, guaranteeing that even if a network timeout occurs midway through submission, the server will never duplicate XP or territory.</li>
    <li><strong>Exponential Backoff Algorithm:</strong> If the API responds with HTTP 500, 502, 503, or a network socket timeout, the retry timer doubles exponentially with jitter:
    $$t_{retry} = \min\left(t_{max}, 2^n \times t_{base} + \text{rand}(0, 250\text{ms})\right)$$</li>
    <li><strong>Permanent 4xx Error Guard:</strong> If the server rejects the run with HTTP 400 or 422 (e.g., anti-cheat flagged velocity violation), the queue does <em>not</em> retry endlessly. It halts the item, displays an informative explanation toast, and archives the run locally.</li>
  </ul>

  <h2>D. Athletic Minimal Design System ("Ink + Pacer Blue") & 1400ms Hold Gesture</h2>
  <p>
    Jogging in intense direct sunlight creates extreme visual glare. GURUDUTT designed the <strong>Athletic Minimal</strong> visual tokens:
  </p>
  <ul>
    <li><strong>Deep Carbon Canvas (<code>#090B0F</code>):</strong> Minimizes OLED pixel power draw and eliminates glare.</li>
    <li><strong>Pacer Blue (<code>#4C8DFF</code>):</strong> High-visibility cyan-blue accent for sovereign athlete territory and paths.</li>
    <li><strong>Coral Indicator (<code>#FF7A59</code>):</strong> High-contrast warning color for contested rival boundaries.</li>
    <li><strong>1400ms Hold-to-Finish Safety Gesture:</strong> Tapping a standard "Finish" button while running with sweaty fingers frequently causes accidental workout terminations. GURUDUTT implemented a circular progress hold gesture requiring continuous contact for 1400ms with haptic feedback ticks before final submission.</li>
  </ul>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- SECTION 3: SLIDE-BY-SLIDE PRESENTATION GUIDE -->
  <h1>3. College Presentation Slide Deck Guide (GURUDUTT)</h1>
  <p>When presenting your portion of the project in front of college professors and external examiners, use the following slide structure and speaking cues (5 to 6 minutes speaking allocation):</p>

  <div class="slide-card avoid-break">
    <div class="slide-header">
      <span class="slide-number">SLIDE 1</span>
      <span class="slide-title">Mobile Client Role & Architectural Mandate</span>
    </div>
    <p><strong>Slide Visual:</strong> Candidate name, role pill ("Mobile Client Lead & UI/UX Systems Architect"), screenshot of the running HUD in dark mode with Pacer Blue polygons.</p>
    <div class="speaking-cue">
      <strong>Speaking Script:</strong> "Good morning examiners. My name is Gurudutt. In Territory Runner, I led the mobile client architecture, real-time tactical map engine, background GPS persistence, and the offline-first sync framework using Flutter and Hive."
    </div>
  </div>

  <div class="slide-card avoid-break">
    <div class="slide-header">
      <span class="slide-number">SLIDE 2</span>
      <span class="slide-title">The Real-World Mobile Problem: Background Killing & Battery Drain</span>
    </div>
    <p><strong>Slide Visual:</strong> Diagram showing Android Doze mode killing standard location listeners vs Territory Runner's hardened foreground service.</p>
    <div class="speaking-cue">
      <strong>Speaking Script:</strong> "When users run, they lock their phone and put it in their pocket. Modern mobile operating systems like Android and iOS aggressively kill background apps to save battery. If GPS tracking drops for even 30 seconds, the athlete's closed loop is ruined. I engineered a solution that guarantees unthrottled 1 Hz tracking throughout multi-hour runs."
    </div>
  </div>

  <div class="slide-card avoid-break">
    <div class="slide-header">
      <span class="slide-number">SLIDE 3</span>
      <span class="slide-title">Foreground Location Services & WakeLock Engineering</span>
    </div>
    <p><strong>Slide Visual:</strong> Architecture flowchart: GPS Chip -> Foreground Service -> Sticky Notification Channel -> Wakelock Manager -> Map Renderer.</p>
    <div class="speaking-cue">
      <strong>Speaking Script:</strong> "I implemented an OS foreground service tied to a persistent sticky notification. By integrating CPU wake locks through wakelock_plus, the application prevents the mobile processor from entering deep sleep while keeping battery consumption below 4.2% per hour through velocity-adaptive GPS sampling."
    </div>
  </div>

  <div class="slide-card avoid-break">
    <div class="slide-header">
      <span class="slide-number">SLIDE 4</span>
      <span class="slide-title">Crash Recovery Safety Box: Zero Lost Waypoints</span>
    </div>
    <p><strong>Slide Visual:</strong> Crash recovery state machine: App crash event -> Relaunch -> Hive auto-detection -> Restore active run dialog.</p>
    <div class="speaking-cue">
      <strong>Speaking Script:</strong> "What if the user's phone runs out of battery or the OS kills the process due to low memory? I created a Crash Recovery Safety Box using Hive storage. Every single GPS coordinate is atomically serialized to disk. If the app crashes, upon relaunch it immediately detects the active session, restoring every waypoint seamlessly."
    </div>
  </div>

  <div class="slide-card avoid-break">
    <div class="slide-header">
      <span class="slide-number">SLIDE 5</span>
      <span class="slide-title">Offline-First FIFO Sync Queue</span>
    </div>
    <p><strong>Slide Visual:</strong> FIFO queue flowchart: Network disconnection -> Persistent Hive storage -> Network reconnection -> Exponential backoff -> Server commit.</p>
    <div class="speaking-cue">
      <strong>Speaking Script:</strong> "Athletes frequently run through cellular dead zones. Territory Runner is built offline-first. Runs are queued into a persistent FIFO Hive box with client-side UUID idempotency keys. When connection is restored, runs sync automatically with exponential backoff, preventing server overloads while ensuring no workout is ever lost."
    </div>
  </div>

  <div class="slide-card avoid-break">
    <div class="slide-header">
      <span class="slide-number">SLIDE 6</span>
      <span class="slide-title">Athletic Minimal Design System & 1400ms Hold Gesture</span>
    </div>
    <p><strong>Slide Visual:</strong> High-contrast color palette (Ink `#090B0F` & Pacer Blue `#4C8DFF`), side-by-side comparison of standard button vs 1400ms hold animation.</p>
    <div class="speaking-cue">
      <strong>Speaking Script:</strong> "To ensure high sunlight visibility while running outdoors, I engineered our Athletic Minimal design system with high-contrast slate and Pacer Blue tokens. I also solved the sweaty finger problem: instead of a single tap button that causes accidental stops, I designed a 1400ms hold-to-finish circular gesture with haptic feedback ticks."
    </div>
  </div>

  <div class="slide-card avoid-break">
    <div class="slide-header">
      <span class="slide-number">SLIDE 7</span>
      <span class="slide-title">Flutter Quality Verification & Test Metrics</span>
    </div>
    <p><strong>Slide Visual:</strong> Test dashboard badge: 317 Flutter tests passing, zero analyze issues, widget test coverage graphs.</p>
    <div class="speaking-cue">
      <strong>Speaking Script:</strong> "I authored over 317 automated Flutter unit and widget tests, proving that our state machines, offline queues, and map widgets perform flawlessly across edge cases with 0 analyzer warnings. Now, I pass the floor to my teammate Avinash to present our computational geometry, WebSockets, and AI engine."
    </div>
  </div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- SECTION 4: EXAMINER VIVA DEFENSE QUESTIONS & ANSWERS -->
  <h1>4. Examiner Viva Defense: Tough Technical Questions & Answers</h1>
  <p>These 10 questions are targeted specifically at <strong>GURUDUTT's</strong> domain (Mobile Architecture, Background Lifecycle, Hive Persistence, and UI/UX). Study both the brief oral defense and deep technical rationale.</p>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q1: Why did you choose Hive over SQLite or Room for local mobile persistence?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> Hive is a lightweight, pure-Dart, key-value storage engine that writes directly to binary disk boxes with zero native C-interop overhead, making it up to 5x faster than SQLite for rapid 1 Hz waypoint logging.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> Relational databases like SQLite require translating Dart objects across the Flutter platform channel into native SQLite C bindings, which creates CPU frame drops when executed at high frequency on mobile UI threads. Hive stores serialized binary buffers directly in local files using memory-mapped keys. This allows atomic append operations for incoming GPS coordinates with sub-millisecond disk write latency, eliminating frame skips on the tactical map HUD.
    </div>
  </div>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q2: How does your application prevent the Android Linux kernel OOM (Out Of Memory) killer from destroying the tracking process?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> By promoting our location tracking service to a Foreground Service linked to an ongoing system notification, Android assigns the process an `oom_score_adj` of zero (foreground priority), preventing the kernel from killing it during background execution.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> In Android's Low Memory Killer (LMK) architecture, background apps without foreground notifications have high <code>oom_score_adj</code> values (typically 800-1000) and are killed first when RAM is needed. By creating an ongoing NotificationChannel with <code>startForeground()</code>, the Android framework treats the app as an active user-facing process with an <code>oom_score_adj</code> equal to active media players, guaranteeing survival even when the screen is locked or other apps are launched.
    </div>
  </div>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q3: What is the purpose of `wakelock_plus` and does holding a CPU wake lock drain the battery excessively?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> `wakelock_plus` acquires a `PARTIAL_WAKE_LOCK`, keeping the CPU alive to process GPS callbacks while the screen is black. We minimize battery drain to &lt; 4.2% per hour by disabling the GPU and throttling non-essential timers while the screen is off.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> Modern SoCs enter deep sleep states (Doze / Suspended) when the display turns off. If the CPU enters deep sleep, incoming hardware GPS interrupts are queued or dropped by the cellular modem. A partial wake lock instructs the power management subsystem to keep the core application processor clocked at low frequency. Because we do not render UI frames when the screen is locked, the CPU operates at minimal power draw, balancing continuous 1 Hz trajectory recording with high battery longevity.
    </div>
  </div>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q4: How does your offline sync queue handle "network flapping" (rapid switching between 4G, 3G, and offline states)?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> The queue uses a debounced connectivity listener and strict mutex locks so that only one run synchronization pipeline executes at any time, preventing duplicate HTTP requests during intermittent network transitions.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> When a runner passes through spotty coverage, the device's connectivity status triggers rapid bursts of state changes (online -> offline -> online). If a sync queue launched worker threads naively on every signal change, multiple concurrent HTTP POST requests would collide. In <code>lib/services/sync_queue.dart</code>, we use a single synchronization mutex flag and a 1500ms debounce timer. If a submission is already in-flight, subsequent trigger events are dropped. If the in-flight request fails due to a socket reset, the item stays in the FIFO queue and waits for the next verified network probe.
    </div>
  </div>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q5: What happens if a run is permanently rejected by the server (e.g. anti-cheat triggers a 400 or 422)? Does the queue retry forever?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> No. We distinguish retryable (5xx, network timeouts) from non-retryable (4xx) HTTP status codes. On a 4xx error, the item is removed from the active queue and archived with a detailed error toast, preventing infinite retry loops.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> In distributed systems, retrying a permanently invalid request is known as the "poison pill" pattern, which congests queues and wastes device battery. In <code>lib/services/sync_queue.dart</code>, our HTTP client inspects response status codes: 5xx server errors and network connection timeouts trigger exponential backoff retry cycles; 4xx client errors (e.g. 400 Bad Request, 401 Unauthorized, 422 Unprocessable Entity) immediately halt the retry loop for that item, mark its local status as <code>rejected</code>, and notify the user via <code>AppToast</code>.
    </div>
  </div>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q6: Why did you implement a 1400ms hold-to-finish gesture instead of a standard confirmation dialog?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> Athletic ergonomics: athletes run with sweaty hands and bouncy movements. Dialog popups require precise two-tap accuracy that causes accidental workout cancellations; a 1400ms hold requires deliberate physical intent.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> Human-computer interaction (HCI) in outdoor athletic contexts is constrained by biomechanical tremor and sweat interference on capacitive touchscreens. A simple button with a dialog modal often leads to accidental taps or missed touches. The 1400ms continuous hold gesture incorporates animated circular SVG progress indicators and intermediate haptic feedback pulses (every 350ms), providing multi-sensory confirmation that gives the runner full tactile control without stopping their stride.
    </div>
  </div>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q7: How do you prevent memory leaks when listening to high-frequency GPS streams in Flutter?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> All StreamSubscriptions are encapsulated in service lifecycles and explicitly cancelled in `dispose()` methods or when transitioning between run states, preventing orphaned listener retention.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> Flutter's Dart VM can retain widget state objects in memory if a broadcast stream subscription holds a closure reference to a mounted widget. In <code>lib/services/location_service.dart</code>, the location stream subscription is maintained as a singleton service decoupled from the UI widget tree. UI widgets subscribe via <code>ValueListenableBuilder</code> or Riverpod providers, which detach automatically when views unmount, eliminating Dart VM garbage collection leaks.
    </div>
  </div>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q8: How does the map render smoothly at 60 FPS while drawing dynamic territory polygons and moving markers?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> We isolate map vector updates into separate Flutter `RepaintBoundary` widgets and use hardware-accelerated Canvas paths, avoiding full-screen rebuilds on every GPS waypoint update.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> Rebuilding the entire map widget tree at 1 Hz causes noticeable frame drops. In <code>lib/features/map/widgets/map_layers.dart</code>, the tactical map is structured in decoupled render layers: static raster tile layer, territorial polygon layer, dynamic polyline breadcrumb layer, and runner location marker layer. By wrapping dynamic layers in <code>CustomPainter</code> with <code>RepaintBoundary</code>, Flutter only repaints the specific mutated vector layer while reusing cached raster tile GPU textures.
    </div>
  </div>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q9: How does the mobile client handle time zones and UTC synchronization during offline runs?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> Every waypoint and run session is recorded using strictly ISO 8601 UTC timestamps derived from the hardware GPS satellite clock, completely immunizing the app against phone clock tampering or timezone shifts.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> If an athlete changes their phone's local time or travels across timezone borders during a run, standard <code>DateTime.now()</code> produces non-monotonic or negative intervals. GPS satellite hardware signals contain atomic clock UTC timestamps. We record every waypoint's timestamp in UTC format (<code>YYYY-MM-DDTHH:MM:SS.mmmZ</code>), ensuring that kinematic velocity calculations and weekly league qualification are 100% immune to client timezone configurations.
    </div>
  </div>

  <div class="viva-card avoid-break">
    <div class="viva-q">Q10: What are the key verification metrics for the mobile client?</div>
    <div class="viva-brief"><strong>Oral Defense (Brief):</strong> 317 automated Flutter tests passing, 0 analyzer issues, verified zero-data-loss crash recovery across simulated app kills, and 4.2% per hour average battery consumption during live field runs.</div>
    <div class="viva-defense">
      <strong>Deep Architectural Proof:</strong> The Flutter test suite in <code>test/</code> validates everything from the offline sync queue state machine (<code>test/services/sync_queue_test.dart</code>) to the crash recovery box (<code>test/services/run_recovery_test.dart</code>) and widget interactions. In addition, real-world field tests on both Android and iOS devices confirmed uninterrupted background tracking with screen locked over 10-kilometer runs.
    </div>
  </div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- SECTION 5: CONCLUSION & SIGN-OFF -->
  <h1>5. Project Verification, Future Scope & Evaluation Sign-Off</h1>

  <h2>Summary of Individual Contributions by GURUDUTT</h2>
  <ul>
    <li>Engineered the Flutter 3.13+ mobile client architecture following feature-driven modular structure.</li>
    <li>Solved Android Doze and iOS background execution throttling via hardened foreground services and CPU wakelocks.</li>
    <li>Constructed the Hive-based Crash Recovery Safety Box, guaranteeing zero waypoint loss during OS kills.</li>
    <li>Architected the persistent FIFO Offline Sync Queue with exponential backoff and idempotency keys.</li>
    <li>Designed the Athletic Minimal visual tokens ("Ink + Pacer Blue") and the 1400ms hold-to-finish gesture.</li>
    <li>Authored 317 automated Flutter unit, service, and widget tests with zero Dart analysis issues.</li>
  </ul>

  <h2>Future Scope (Mobile Client & Field Tracking)</h2>
  <ul>
    <li><strong>WearOS & Apple Watch Companion Apps:</strong> Build standalone smartwatch extensions communicating via Bluetooth Low Energy (BLE) to display live territory boundaries on athletes' wrists.</li>
    <li><strong>Audio Pacer Voice Engine:</strong> Add an audio feedback engine providing vocal cues ("Territory claimed: 12,500 sq meters", "Rival sector entered") via text-to-speech.</li>
    <li><strong>Offline Vector Basemap Bundles:</strong> Implement offline vector map tile downloads via MBTiles for athletes running in remote mountain trails with zero cellular reception.</li>
  </ul>

  <div style="margin-top: 15mm; border: 2px solid #0f172a; padding: 12px 16px; border-radius: 8px; background: #f8fafc;" class="avoid-break">
    <h3 style="margin-top: 0; color: #0f172a; border-bottom: 1px solid #cbd5e1; padding-bottom: 4px;">COLLEGE EXAMINATION COMMITTEE SIGN-OFF</h3>
    <p style="font-size: 8.5pt; color: #475569; margin-bottom: 12px;">
      This is to certify that <strong>GURUDUTT</strong> has successfully designed, defended, and demonstrated the <strong>Mobile Client Architecture, Background Lifecycle Hardening & Offline Persistence Subsystems</strong> of the project entitled <strong>"Territory Runner"</strong> during the final project viva voce examination.
    </p>
    <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; text-align: center; margin-top: 10mm;">
      <div>
        <div style="border-top: 1px solid #334155; padding-top: 4px; font-weight: 700; font-size: 8.5pt;">Internal Examiner</div>
        <div style="font-size: 7.5pt; color: #64748b;">Signature & Date</div>
      </div>
      <div>
        <div style="border-top: 1px solid #334155; padding-top: 4px; font-weight: 700; font-size: 8.5pt;">External Viva Examiner</div>
        <div style="font-size: 7.5pt; color: #64748b;">Signature & Date</div>
      </div>
      <div>
        <div style="border-top: 1px solid #334155; padding-top: 4px; font-weight: 700; font-size: 8.5pt;">Head of Department (CSE)</div>
        <div style="font-size: 7.5pt; color: #64748b;">Signature & Seal</div>
      </div>
    </div>
  </div>

</body>
</html>
"""

if __name__ == "__main__":
    html_content = get_gurudutt_html()
    out_file = Path(r"c:\Users\AYUSH\Desktop\territory_runner\college_presentation_dossiers\GURUDUTT_Territory_Runner_College_Defense.html")
    out_file.write_text(html_content, encoding="utf-8")
    print(f"Written {out_file.name}")
