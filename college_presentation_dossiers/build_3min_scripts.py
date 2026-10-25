import os
import sys
import subprocess
from pathlib import Path

BASE_DIR = Path(r"c:\Users\AYUSH\Desktop\territory_runner")
DOSSIER_DIR = BASE_DIR / "college_presentation_dossiers"
DESKTOP_DIR = Path(r"C:\Users\AYUSH\Desktop\College_Project_PDFs")
DOWNLOADS_DIR = Path(r"C:\Users\AYUSH\Downloads")
EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

SHARED_CSS = r"""
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap');

@page {
  size: A4 portrait;
  margin: 12mm 14mm 12mm 14mm;
  @bottom-right {
    content: "Page " counter(page) " of 3";
    font-size: 8pt;
    font-family: 'Inter', sans-serif;
    color: #64748b;
  }
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  color: #0f172a;
  background-color: #ffffff;
  line-height: 1.45;
  font-size: 9.5pt;
  -webkit-print-color-adjust: exact;
  print-color-adjust: exact;
}

.page-break { page-break-before: always; break-before: page; }
.avoid-break { page-break-inside: avoid; break-inside: avoid; }

.header-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 2px solid #2563eb;
  padding-bottom: 8px;
  margin-bottom: 12px;
}

.header-left h1 {
  font-size: 15pt;
  font-weight: 800;
  color: #0f172a;
  line-height: 1.2;
}

.header-left .sub {
  font-size: 9pt;
  color: #475569;
  font-weight: 600;
}

.header-right {
  text-align: right;
}

.badge {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 9999px;
  font-size: 8pt;
  font-weight: 700;
  text-transform: uppercase;
}

.badge-blue { background: #eff6ff; color: #1d4ed8; border: 1px solid #bfdbfe; }
.badge-purple { background: #faf5ff; color: #6b21a8; border: 1px solid #e9d5ff; }
.badge-coral { background: #fff1f2; color: #be123c; border: 1px solid #fecdd3; }
.badge-timer { background: #0f172a; color: #ffffff; padding: 3px 8px; border-radius: 4px; font-family: 'JetBrains Mono', monospace; font-size: 8pt; }

.meta-strip {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 10px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 8px 12px;
  margin-bottom: 14px;
}

.meta-item .lbl { font-size: 7pt; font-weight: 700; color: #64748b; text-transform: uppercase; }
.meta-item .val { font-size: 9pt; font-weight: 700; color: #0f172a; }

.script-box {
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  padding: 10px 14px;
  margin-bottom: 11px;
  background: #ffffff;
}

.script-box-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
  border-bottom: 1px solid #f1f5f9;
  padding-bottom: 4px;
}

.minute-title {
  font-size: 10pt;
  font-weight: 700;
  color: #0f172a;
}

.speech-text {
  font-size: 9.5pt;
  line-height: 1.5;
  color: #1e293b;
}

.speech-text strong {
  color: #0f172a;
}

.action-tip {
  font-size: 8pt;
  color: #475569;
  font-style: italic;
  margin-top: 6px;
  background: #f8fafc;
  padding: 4px 8px;
  border-radius: 4px;
  border-left: 3px solid #2563eb;
}

/* Slide Cards */
.slide-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 12px;
}

.slide-card {
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  padding: 8px 10px;
  background: #ffffff;
}

.slide-top {
  display: flex;
  justify-content: space-between;
  font-size: 8pt;
  font-weight: 700;
  color: #2563eb;
  margin-bottom: 4px;
}

.slide-heading {
  font-size: 9pt;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 4px;
}

.slide-points {
  font-size: 8pt;
  color: #334155;
  padding-left: 14px;
}

.slide-points li { margin-bottom: 3px; }

/* Viva Card */
.viva-box {
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 8px 10px;
  margin-bottom: 8px;
  background: #ffffff;
}

.viva-q {
  font-size: 8.5pt;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 3px;
}

.viva-a {
  font-size: 8pt;
  color: #1e40af;
  background: #eff6ff;
  padding: 4px 6px;
  border-radius: 4px;
  line-height: 1.35;
}

.viva-proof {
  font-size: 7.5pt;
  color: #475569;
  margin-top: 3px;
}

.code-pill {
  font-family: 'JetBrains Mono', monospace;
  background: #f1f5f9;
  padding: 1px 3px;
  font-size: 7.5pt;
  border-radius: 3px;
}

.sign-box {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 12px;
  border-top: 1px solid #cbd5e1;
  padding-top: 10px;
  margin-top: 14px;
  text-align: center;
}

.sign-line {
  border-top: 1px dashed #94a3b8;
  padding-top: 3px;
  font-size: 7.5pt;
  color: #475569;
  font-weight: 600;
}
"""

def get_ayush_3min_html():
    content = r"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>AYUSH — 3-Minute Presentation Speaking Script</title>
  <style>__CSS__</style>
</head>
<body>

  <!-- PAGE 1: 3-MINUTE SPOKEN SCRIPT -->
  <div class="header-bar">
    <div class="header-left">
      <h1>AYUSH — 3-Minute College Presentation Script</h1>
      <div class="sub">Territory Runner | Subsystem Focus: Backend, Concurrency & Spatial DB</div>
    </div>
    <div class="header-right">
      <span class="badge badge-timer">TOTAL TIME: 3:00 MIN</span><br>
      <span class="badge badge-blue" style="margin-top: 4px;">Role: Backend Lead</span>
    </div>
  </div>

  <div class="meta-strip">
    <div class="meta-item"><div class="lbl">Presenter</div><div class="val">AYUSH</div></div>
    <div class="meta-item"><div class="lbl">Assigned Time</div><div class="val">Minute 0:00 to 3:00 (3 Mins)</div></div>
    <div class="meta-item"><div class="lbl">Core Stack</div><div class="val">Go 1.24, PostGIS 3.4, Advisory Locks</div></div>
  </div>

  <!-- MINUTE 1 -->
  <div class="script-box">
    <div class="script-box-header">
      <span class="minute-title">⏱️ MINUTE 1 (0:00 – 1:00) : Hook & Server-Authoritative Architecture</span>
      <span class="badge badge-timer">0:00 - 1:00</span>
    </div>
    <div class="speech-text">
      "Good morning respected professors and examiners. My name is <strong>Ayush</strong>. In <em>Territory Runner</em>, I architected the <strong>server-authoritative backend, PostGIS spatial database, distributed concurrency control, and kinematic anti-cheat</strong>.<br><br>
      Traditional fitness trackers like Strava only record passive 1D polylines without real-world conflict. Territory Runner transforms outdoor workouts into an active spatial strategy platform where athletes physically capture <strong>arbitrary 2D closed-loop polygons</strong>. Because mobile devices operate in untrusted environments susceptible to GPS spoofing and clock manipulation, our core architectural rule is: <em>the client proposes, but the server authoritatively validates, serializes, and commits</em>."
    </div>
    <div class="action-tip">👉 <strong>Action:</strong> Click Slide 1 & Slide 2. Point to the architecture diagram showing mobile requests flowing into the Chi REST middleware and PostgreSQL.</div>
  </div>

  <!-- MINUTE 2 -->
  <div class="script-box">
    <div class="script-box-header">
      <span class="minute-title">⏱️ MINUTE 2 (1:00 – 2:00) : Spatial Concurrency & Kinematic Anti-Cheat</span>
      <span class="badge badge-timer">1:00 - 2:00</span>
    </div>
    <div class="speech-text">
      "The most complex engineering challenge was <strong>spatial concurrency control</strong>. When rival runners compete in the same park, multiple writes hit the same geographic polygons. Optimistic Concurrency Control fails because discarded PostGIS difference queries waste massive CPU. Redis Redlock introduces split-brain risk.<br><br>
      I solved this using <strong>PostgreSQL transaction-scoped advisory locks</strong> via <code>pg_advisory_xact_lock</code>. This serializes spatial mutations—<code>ST_Union</code> to claim territory and <code>ST_Difference</code> to carve rivals—with zero orphaned lock leaks.<br><br>
      Additionally, to prevent players from driving cars or using mock GPS apps, I authored a <strong>kinematic anti-cheat filter</strong> in Go. It enforces hard athletic velocity ceilings: <strong>25 km/h for running</strong> and <strong>50 km/h for cycling</strong>, with a max acceleration limit of <strong>4.5 m/s²</strong>, automatically rejecting vehicle spoofers."
    </div>
    <div class="action-tip">👉 <strong>Action:</strong> Switch to Slide 3. Highlight the Advisory Lock comparison table and the speed ceiling boundaries.</div>
  </div>

  <!-- MINUTE 3 -->
  <div class="script-box">
    <div class="script-box-header">
      <span class="minute-title">⏱️ MINUTE 3 (2:00 – 3:00) : Idempotency, Verification & Handover</span>
      <span class="badge badge-timer">2:00 - 3:00</span>
    </div>
    <div class="speech-text">
      "When mobile clients submit runs in spotty network zones, retried requests can cause duplicate territory claims. I enforced strict <strong>idempotency keys</strong> in PostgreSQL: duplicate submissions return HTTP 200 with cached capture results without double-crediting XP or land.<br><br>
      To verify the backend, I authored <strong>79 automated Go tests</strong> covering advisory lock stress, kinematic limits, and spatial transactions. Under load, our p95 transaction latency remains under <strong>35 milliseconds</strong>, and the entire backend is containerized in Alpine Docker.<br><br>
      Now, I hand over to my teammate <strong>Gurudutt</strong>, who will present the mobile UI design and athletic design system."
    </div>
    <div class="action-tip">👉 <strong>Action:</strong> Switch to Slide 4. Show the 79 Go tests passing badge and nod toward Gurudutt for a smooth transition.</div>
  </div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- PAGE 2: SLIDE PRESENTATION CHEAT SHEET -->
  <div class="header-bar">
    <div class="header-left">
      <h1>AYUSH — Slide Deck Presentation Guide</h1>
      <div class="sub">Exactly what to display and point at during your 3 minutes</div>
    </div>
    <div class="header-right">
      <span class="badge badge-blue">4 Slides Total</span>
    </div>
  </div>

  <div class="slide-grid">
    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 1 (0:00 - 0:30)</span><span>INTRO & PROBLEM</span></div>
      <div class="slide-heading">The Distributed Spatial Challenge</div>
      <ul class="slide-points">
        <li>Strava passive 1D linear tracking vs Territory Runner 2D organic polygons.</li>
        <li>Untrusted mobile environments: GPS spoofing, clock skew, packet sniffing.</li>
        <li><strong>Architecture Rule:</strong> Server-Authoritative Go 1.24 + PostGIS 3.4 engine.</li>
      </ul>
    </div>

    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 2 (0:30 - 1:00)</span><span>BACKEND ARCHITECTURE</span></div>
      <div class="slide-heading">Go Chi REST & Middleware Pipeline</div>
      <ul class="slide-points">
        <li>Chi router with rate limiting, CORS whitelist, body limit guards.</li>
        <li>Firebase RS256 JWT public key verification with in-memory JWKS caching.</li>
        <li>Spatial Entity-Relationship schema: <code>users</code>, <code>territories</code>, <code>runs</code>.</li>
      </ul>
    </div>

    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 3 (1:00 - 2:00)</span><span>LOCKS & ANTI-CHEAT</span></div>
      <div class="slide-heading">Advisory Locks & Kinematic Velocity Ceilings</div>
      <ul class="slide-points">
        <li><code>pg_advisory_xact_lock(hashtext('territory_mutation_lock'))</code>.</li>
        <li>Zero deadlocks, 100% ACID compliance, auto-released on commit/rollback.</li>
        <li>Anti-Cheat Ceilings: Running: 25 km/h | Cycling: 50 km/h | Accel: 4.5 m/s².</li>
      </ul>
    </div>

    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 4 (2:00 - 3:00)</span><span>INTEGRITY & METRICS</span></div>
      <div class="slide-heading">Idempotency & Verification Metrics</div>
      <ul class="slide-points">
        <li>Client UUID <code>idempotency_key</code> preventing double territory claims.</li>
        <li>PostGIS <code>ST_MakeValid</code> repairing bowtie self-intersections.</li>
        <li><strong>79 Go Tests Passing</strong> | p95 Latency &lt; 35ms | Minimal Alpine Docker container.</li>
      </ul>
    </div>
  </div>

  <div class="script-box" style="margin-top: 10px;">
    <div class="script-box-header">
      <span class="minute-title">📋 Ayush's Quick Reference Pocket Card</span>
      <span class="badge badge-blue">Code & Files</span>
    </div>
    <div style="font-size: 8pt; line-height: 1.4; color: #334155;">
      • <strong>Server Entry:</strong> <span class="code-pill">backend/cmd/server/main.go</span><br>
      • <strong>Spatial DB Store:</strong> <span class="code-pill">backend/internal/store/postgres.go</span> (<code>ST_Union</code>, <code>ST_Difference</code>, <code>ST_MakeValid</code>)<br>
      • <strong>Advisory Locking:</strong> <span class="code-pill">backend/internal/store/advisory_lock.go</span><br>
      • <strong>Anti-Cheat Engine:</strong> <span class="code-pill">backend/internal/anticheat/kinematic.go</span><br>
      • <strong>Key SQL:</strong> <code>SELECT pg_advisory_xact_lock(hashtext('territory_mutation_lock'));</code>
    </div>
  </div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- PAGE 3: TOP 4 EXAMINER VIVA DEFENSE QUESTIONS -->
  <div class="header-bar">
    <div class="header-left">
      <h1>AYUSH — Examiner Viva Defense Cheat Sheet</h1>
      <div class="sub">Top 4 killer examiner questions with rapid 15-second oral defenses</div>
    </div>
    <div class="header-right">
      <span class="badge badge-blue">Examiner Defense</span>
    </div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q1: Why use PostgreSQL advisory locks (`pg_advisory_xact_lock`) instead of Redis Redlock or row locks?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "Row locks cannot lock rows that don't exist yet—like newly carved rival territory slices—and table locks freeze read queries. Redis Redlock requires managing dual state and risks split-brain errors under clock skew. `pg_advisory_xact_lock` executes inside the PostgreSQL kernel, serializes spatial writes cleanly, and automatically releases on commit or rollback."</div>
    <div class="viva-proof">📁 Implemented in: <code>backend/internal/store/postgres.go#L180-L215</code></div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q2: How does your kinematic filter avoid falsely flagging an athletic human sprinter?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "We use world-record human biomechanics. Sprinters top out at ~44 km/h for brief bursts but cannot sustain it, and humans exhibit natural acceleration-deceleration curves. Our running ceiling is 25 km/h sustained with a 4.5 m/s² acceleration ceiling over a sliding time window. Vehicles show prolonged high velocities across turns that easily trigger our 0.70 anomaly threshold."</div>
    <div class="viva-proof">📁 Implemented in: <code>backend/internal/anticheat/kinematic.go#L45-L95</code></div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q3: How does PostGIS `ST_MakeValid` handle self-intersecting 'bowtie' loops from GPS jitter?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "In OGC geometry, self-intersecting loops break simple feature rules and throw GEOS TopologyExceptions. We pass incoming WKT through <code>ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))</code>. Under the hood, GEOS splits bowtie self-crossings into valid multi-polygon sub-rings, and collection extract preserves only 2D polygons while stripping 1D antenna lines."</div>
    <div class="viva-proof">📁 Implemented in: <code>backend/internal/store/postgres.go#L240-L260</code></div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q4: How do you verify Firebase JWT tokens on the Go backend without calling Google on every request?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "We fetch Google's public JWKS certificates once on server startup and cache them in memory. Every incoming request is verified in-process using local asymmetric RS256 RSA public key cryptography. We only make a network call to refresh certificates if an unknown key ID (`kid`) is encountered."</div>
    <div class="viva-proof">📁 Implemented in: <code>backend/internal/auth/verifier.go#L30-L75</code></div>
  </div>

  <div class="sign-box">
    <div class="sign-line">Candidate Signature<br><strong>AYUSH</strong></div>
    <div class="sign-line">Internal Project Guide<br>Dept. of CSE</div>
    <div class="sign-line">External Viva Examiner<br>University Board</div>
  </div>

</body>
</html>
"""
    return content.replace("__CSS__", SHARED_CSS)

def get_gurudutt_3min_html():
    content = r"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>GURUDUTT — 3-Minute Presentation Speaking Script</title>
  <style>__CSS__</style>
</head>
<body>

  <!-- PAGE 1: 3-MINUTE SPOKEN SCRIPT -->
  <div class="header-bar">
    <div class="header-left">
      <h1>GURUDUTT — 3-Minute College Presentation Script</h1>
      <div class="sub">Territory Runner | Subsystem Focus: UI/UX Design & Athletic Ergonomics</div>
    </div>
    <div class="header-right">
      <span class="badge badge-timer">TOTAL TIME: 3:00 MIN</span><br>
      <span class="badge badge-purple" style="margin-top: 4px;">Role: UI/UX Lead</span>
    </div>
  </div>

  <div class="meta-strip">
    <div class="meta-item"><div class="lbl">Presenter</div><div class="val">GURUDUTT</div></div>
    <div class="meta-item"><div class="lbl">Assigned Time</div><div class="val">Minute 3:00 to 6:00 (3 Mins)</div></div>
    <div class="meta-item"><div class="lbl">Core Stack</div><div class="val">Flutter 3.13+, Ink + Blue, Map HUD</div></div>
  </div>

  <!-- MINUTE 1 -->
  <div class="script-box">
    <div class="script-box-header">
      <span class="minute-title">⏱️ MINUTE 1 (3:00 – 4:00) : Athletic Ergonomics & Design Philosophy</span>
      <span class="badge badge-timer">3:00 - 4:00</span>
    </div>
    <div class="speech-text">
      "Good morning respected examiners. My name is <strong>Gurudutt</strong>, and in <em>Territory Runner</em>, I led the <strong>UI/UX design, visual design system, tactical map interface, and athletic ergonomics</strong> built with Flutter.<br><br>
      When an athlete runs outdoors, they face extreme visual and physical constraints that break typical app designs: <strong>harsh direct sunlight</strong> washes out washed-out pastel screens, and <strong>physical bouncing and sweaty fingers</strong> make standard small buttons impossible to tap reliably.<br><br>
      To solve this, I designed our bespoke <strong>Athletic Minimal Design System: Ink and Pacer Blue</strong>. We rejected generic white backgrounds and colorful arcade clutter, building a calm, high-contrast tactical dark interface inspired by aviation heads-up displays."
    </div>
    <div class="action-tip">👉 <strong>Action:</strong> Switch to Slide 5. Display the high-contrast Ink & Pacer Blue color tokens and running HUD mockup.</div>
  </div>

  <!-- MINUTE 2 -->
  <div class="script-box">
    <div class="script-box-header">
      <span class="minute-title">⏱️ MINUTE 2 (4:00 – 5:00) : Tactical Map HUD & 1400ms Hold Gesture</span>
      <span class="badge badge-timer">4:00 - 5:00</span>
    </div>
    <div class="speech-text">
      "Our color architecture is built around three calibrated tokens: a <strong>deep carbon canvas (<code>#090B0F</code>)</strong> which eliminates screen glare and minimizes OLED battery consumption; crisp <strong>Pacer Blue (<code>#4C8DFF</code>)</strong> for sovereign athlete trails and conquered sectors; and <strong>Coral (<code>#FF7A59</code>)</strong> for contested rival boundaries.<br><br>
      On the <strong>Tactical Map HUD</strong>, dynamic vector polylines and polygons update continuously at <strong>60 FPS</strong>. I isolated rendering layers using Flutter <code>RepaintBoundary</code> widgets, preventing heavy map tile re-renders on every GPS tick.<br><br>
      To solve the sweaty-finger problem, I eliminated the standard 'Finish' button. In outdoor testing, runners frequently stop runs by mistake. I created a circular <strong>1400-millisecond Hold-to-Finish gesture</strong> with intermediate haptic feedback pulses every 350 milliseconds, requiring deliberate physical intent."
    </div>
    <div class="action-tip">👉 <strong>Action:</strong> Switch to Slide 6. Show the 1400ms Hold-to-Finish circular animation and map layer diagram.</div>
  </div>

  <!-- MINUTE 3 -->
  <div class="script-box">
    <div class="script-box-header">
      <span class="minute-title">⏱️ MINUTE 3 (5:00 – 6:00) : AppToast Framework, Metrics & Handover</span>
      <span class="badge badge-timer">5:00 - 6:00</span>
    </div>
    <div class="speech-text">
      "For in-run athlete feedback, I built <strong>AppToast</strong>—a unified notification overlay that alerts runners to GPS signal degradation, rival territory contestation, and server area reconciliations without obstructing the map viewport.<br><br>
      The UI operates on zero raster fallbacks, using vector SVGs and typography for razor-sharp rendering on any screen density. The mobile UI is validated across <strong>317 automated Flutter tests</strong> with zero layout overflow errors and clean Dart static analysis.<br><br>
      Now, I pass the floor to my teammate <strong>Avinash</strong>, who will present our computational geometry algorithms, loop detection, and project documentation."
    </div>
    <div class="action-tip">👉 <strong>Action:</strong> Switch to Slide 7. Show the 317 Flutter tests passing badge and nod toward Avinash.</div>
  </div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- PAGE 2: SLIDE PRESENTATION CHEAT SHEET -->
  <div class="header-bar">
    <div class="header-left">
      <h1>GURUDUTT — Slide Deck Presentation Guide</h1>
      <div class="sub">Exactly what to display and point at during your 3 minutes</div>
    </div>
    <div class="header-right">
      <span class="badge badge-purple">4 Slides Total</span>
    </div>
  </div>

  <div class="slide-grid">
    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 5 (3:00 - 3:45)</span><span>DESIGN PHILOSOPHY</span></div>
      <div class="slide-heading">Athletic Minimal Design System</div>
      <ul class="slide-points">
        <li>Direct sunlight glare vs high-contrast tactical dark interface.</li>
        <li><strong>Ink Canvas (`#090B0F`):</strong> Zero glare, maximum OLED battery savings.</li>
        <li><strong>Pacer Blue (`#4C8DFF`):</strong> Crisp high-visibility athletic sovereign color.</li>
        <li><strong>Coral (`#FF7A59`):</strong> High-alert rival indicator.</li>
      </ul>
    </div>

    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 6 (3:45 - 4:30)</span><span>TACTICAL MAP HUD</span></div>
      <div class="slide-heading">60 FPS Map Layers & Vector Rendering</div>
      <ul class="slide-points">
        <li>Multi-layer architecture: ArcGIS Dark Tiles -> Polygons -> Trails -> HUD.</li>
        <li><code>RepaintBoundary</code> isolation preventing full map widget rebuilds.</li>
        <li>Smooth runner marker heading rotation and position interpolation.</li>
      </ul>
    </div>

    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 7 (4:30 - 5:15)</span><span>ATHLETIC ERGONOMICS</span></div>
      <div class="slide-heading">1400ms Hold-to-Finish & AppToast</div>
      <ul class="slide-points">
        <li>Accidental touch prevention: sweat and physical bouncing mitigation.</li>
        <li>1400ms circular hold gesture with haptic vibration feedback.</li>
        <li>Unified AppToast framework for server area reconciliation alerts.</li>
      </ul>
    </div>

    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 8 (5:15 - 6:00)</span><span>UI VERIFICATION</span></div>
      <div class="slide-heading">Zero Raster Fallback & 317 Tests</div>
      <ul class="slide-points">
        <li>Pure vector SVGs & typography across 320dpi to 560dpi mobile screens.</li>
        <li><strong>317 Automated Flutter Tests Passing</strong> with 0 analyze warnings.</li>
        <li>Responsive HUD adapting cleanly across Android and iOS notch layouts.</li>
      </ul>
    </div>
  </div>

  <div class="script-box" style="margin-top: 10px;">
    <div class="script-box-header">
      <span class="minute-title">📋 Gurudutt's Quick Reference Pocket Card</span>
      <span class="badge badge-purple">Code & Files</span>
    </div>
    <div style="font-size: 8pt; line-height: 1.4; color: #334155;">
      • <strong>Theme Tokens:</strong> <span class="code-pill">lib/core/theme/</span> (Carbon `#090B0F`, Pacer Blue `#4C8DFF`)<br>
      • <strong>Tactical Map Layers:</strong> <span class="code-pill">lib/features/map/widgets/map_layers.dart</span><br>
      • <strong>Hold-to-Finish Logic:</strong> <span class="code-pill">lib/features/gameplay/territory_service.dart</span><br>
      • <strong>Notification Toasts:</strong> <span class="code-pill">lib/ui/widgets/app_toast.dart</span><br>
      • <strong>Key Gesture:</strong> 1400ms continuous contact duration + 350ms haptic ticks.
    </div>
  </div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- PAGE 3: TOP 4 EXAMINER VIVA DEFENSE QUESTIONS -->
  <div class="header-bar">
    <div class="header-left">
      <h1>GURUDUTT — Examiner Viva Defense Cheat Sheet</h1>
      <div class="sub">Top 4 killer examiner questions with rapid 15-second oral defenses</div>
    </div>
    <div class="header-right">
      <span class="badge badge-purple">Examiner Defense</span>
    </div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q1: Why did you build a custom dark theme instead of using standard Material 3 Light Theme?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "Athletic usability: white and pastel screens wash out completely in direct noon sunlight and cause severe pupil glare. Furthermore, running GPS apps consume significant battery; our Ink `#090B0F` canvas turns off OLED pixels on modern AMOLED displays, reducing screen power drain by up to 35% during long outdoor runs."</div>
    <div class="viva-proof">📁 Implemented in: <code>lib/core/theme/app_theme.dart</code></div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q2: How does the 1400ms hold gesture prevent accidental input during exercise?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "Biomechanical tremor: runners in motion with sweaty fingers frequently register accidental double-taps or pocket-rubs on standard modal dialogs. Our 1400ms hold gesture requires continuous finger contact, animates an SVG circular progress ring, and pulses haptic ticks every 350ms, confirming deliberate physical intent without stopping their run."</div>
    <div class="viva-proof">📁 Implemented in: <code>lib/features/gameplay/territory_service.dart</code></div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q3: How do you keep the tactical map rendering at 60 FPS without frame stutter during live GPS updates?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "By using isolated Flutter `RepaintBoundary` widgets. The static map tiles, sovereign territory polygons, and live breadcrumb trail are decoupled into separate CustomPainters. When a new GPS waypoint arrives at 1 Hz, Flutter repaints only the dynamic breadcrumb vector layer while reusing cached raster tile GPU textures."</div>
    <div class="viva-proof">📁 Implemented in: <code>lib/features/map/widgets/map_layers.dart</code></div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q4: How does the UI handle area reconciliation if the server's PostGIS area differs from the local preview?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "Via our non-intrusive AppToast notification framework. The local preview displays an instant optimistic polygon. When the HTTP 201 response returns the authoritative PostGIS area, if the variance exceeds 0.5%, an AppToast gently reconciles the metric on screen without interrupting the athlete's workout summary."</div>
    <div class="viva-proof">📁 Implemented in: <code>lib/ui/widgets/app_toast.dart</code></div>
  </div>

  <div class="sign-box">
    <div class="sign-line">Candidate Signature<br><strong>GURUDUTT</strong></div>
    <div class="sign-line">Internal Project Guide<br>Dept. of CSE</div>
    <div class="sign-line">External Viva Examiner<br>University Board</div>
  </div>

</body>
</html>
"""
    return content.replace("__CSS__", SHARED_CSS)

def get_avinash_3min_html():
    content = r"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>AVINASH — 3-Minute Presentation Speaking Script</title>
  <style>__CSS__</style>
</head>
<body>

  <!-- PAGE 1: 3-MINUTE SPOKEN SCRIPT -->
  <div class="header-bar">
    <div class="header-left">
      <h1>AVINASH — 3-Minute College Presentation Script</h1>
      <div class="sub">Territory Runner | Subsystem Focus: Algorithms & Master Documentation</div>
    </div>
    <div class="header-right">
      <span class="badge badge-timer">TOTAL TIME: 3:00 MIN</span><br>
      <span class="badge badge-coral" style="margin-top: 4px;">Role: Algorithms & Docs Lead</span>
    </div>
  </div>

  <div class="meta-strip">
    <div class="meta-item"><div class="lbl">Presenter</div><div class="val">AVINASH</div></div>
    <div class="meta-item"><div class="lbl">Assigned Time</div><div class="val">Minute 6:00 to 9:00 (3 Mins)</div></div>
    <div class="meta-item"><div class="lbl">Core Stack</div><div class="val">Clipper2, Shoelace Math, Jordan Curve, Docs</div></div>
  </div>

  <!-- MINUTE 1 -->
  <div class="script-box">
    <div class="script-box-header">
      <span class="minute-title">⏱️ MINUTE 1 (6:00 – 7:00) : Lasso Loop Closure Algorithm</span>
      <span class="badge badge-timer">6:00 - 7:00</span>
    </div>
    <div class="speech-text">
      "Good morning professors and examiners. My name is <strong>Avinash</strong>. In <em>Territory Runner</em>, I was responsible for the <strong>computational geometry algorithms, cross-platform mathematical parity, and master project documentation</strong>.<br><br>
      When an athlete runs outdoors, they rarely return to their exact millimeter starting coordinate. Instead, they run an organic loop and cross their own historical breadcrumb track. I formulated our <strong>Lasso Closure Algorithm</strong>.<br><br>
      To prevent GPS drift from creating false loops, closure detection activates only after running <strong>150 meters</strong>. When the current coordinate comes within a <strong>25-meter proximity buffer</strong> of any past segment, the algorithm calculates the exact line segment intersection point, slices the closed polygon ring, and discards the dangling 'lasso tail' in real time using Clipper2."
    </div>
    <div class="action-tip">👉 <strong>Action:</strong> Switch to Slide 8. Point at the lasso loop closure diagram showing track crossing and virtual intersection point P*.</div>
  </div>

  <!-- MINUTE 2 -->
  <div class="script-box">
    <div class="script-box-header">
      <span class="minute-title">⏱️ MINUTE 2 (7:00 – 8:00) : Algorithmic Parity & Donut Hole Classifier</span>
      <span class="badge badge-timer">7:00 - 8:00</span>
    </div>
    <div class="speech-text">
      "A fundamental theoretical problem was <strong>algorithmic parity</strong> between client and server. Evaluating complex ellipsoidal geodesics on mobile UI threads causes UI stutters. I implemented a scaled planar <strong>Shoelace formula</strong> on Flutter, correcting for latitude distortion by scaling longitude differences with the cosine of the mean latitude.<br><br>
      To guarantee fairness, I established <strong>15 cross-platform golden test fixtures</strong>. We mathematically proved that the client's Shoelace preview and the server's PostGIS <code>ST_Area</code> calculation match with <strong>less than 0.5% variance</strong> across all shapes.<br><br>
      Additionally, I authored our <strong>Ray-Casting Donut Hole Classifier</strong> based on the Jordan Curve Theorem. If an athlete runs around an obstacle like a lake, semi-infinite horizontal rays determine whether enclosed rings are exterior land or inaccessible interior holes."
    </div>
    <div class="action-tip">👉 <strong>Action:</strong> Switch to Slide 9. Highlight the Shoelace formula, the 0.5% parity proof, and the ray-casting visual.</div>
  </div>

  <!-- MINUTE 3 -->
  <div class="script-box">
    <div class="script-box-header">
      <span class="minute-title">⏱️ MINUTE 3 (8:00 – 9:00) : Master Documentation, Golden Verification & Conclusion</span>
      <span class="badge badge-timer">8:00 - 9:00</span>
    </div>
    <div class="speech-text">
      "On the documentation front, I compiled our comprehensive <strong>Software Requirements Specification (SRS), architectural sequence diagrams, and API contract specifications</strong>, ensuring clear module boundaries across our team.<br><br>
      Our geometry engine is verified by <strong>15 golden geospatial test suites</strong> running in both Dart and Go, covering figure-8s, tiny loops, cycling routes, and pause/resumes.<br><br>
      In conclusion, Territory Runner proves that server-authoritative distributed systems, high-contrast athletic UI, and rigorous computational geometry can unite into an exceptional fitness platform. My teammates Ayush, Gurudutt, and I are now ready for your questions."
    </div>
    <div class="action-tip">👉 <strong>Action:</strong> Switch to Slide 10. Display the summary dashboard, invite questions, and stand together as a team.</div>
  </div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- PAGE 2: SLIDE PRESENTATION CHEAT SHEET -->
  <div class="header-bar">
    <div class="header-left">
      <h1>AVINASH — Slide Deck Presentation Guide</h1>
      <div class="sub">Exactly what to display and point at during your 3 minutes</div>
    </div>
    <div class="header-right">
      <span class="badge badge-coral">3 Slides Total</span>
    </div>
  </div>

  <div class="slide-grid">
    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 8 (6:00 - 6:50)</span><span>LASSO ALGORITHM</span></div>
      <div class="slide-heading">Lasso Loop Closure Snapping</div>
      <ul class="slide-points">
        <li>Self-crossing detection: runner crossing their own track breadcrumbs.</li>
        <li><strong>Activation Guards:</strong> Distance &gt; 150m, Snap radius $R_{snap} = 25\text{m}$.</li>
        <li>Line intersection math: $P = A + t(B - A) = C + u(D - C)$.</li>
        <li>Automatic polygon ring extraction & dangling tail pruning.</li>
      </ul>
    </div>

    <div class="slide-card">
      <div class="slide-top"><span>SLIDE 9 (6:50 - 7:40)</span><span>GEOMETRIC PARITY</span></div>
      <div class="slide-heading">Shoelace vs PostGIS & Donut Holes</div>
      <ul class="slide-points">
        <li>Scaled planar Shoelace on mobile: $A = \frac{1}{2} |\sum (x_i y_{i+1} - x_{i+1} y_i)|$.</li>
        <li><strong>Strict Parity:</strong> &lt; 0.5% area discrepancy against PostGIS <code>ST_Area</code>.</li>
        <li>Ray-Casting Donut Classifier: Jordan Curve Theorem detecting interior voids.</li>
      </ul>
    </div>

    <div class="slide-card" style="grid-column: span 2;">
      <div class="slide-top"><span>SLIDE 10 (7:40 - 8:30)</span><span>DOCUMENTATION & SUMMARY</span></div>
      <div class="slide-heading">Master Project Documentation & Team Verification Metrics</div>
      <ul class="slide-points">
        <li>Complete Software Engineering Documentation: SRS, Architecture Diagrams, API Contracts, and Viva Defense Guide.</li>
        <li>15 Cross-Platform Golden Geospatial Fixtures passing in both Dart and Go.</li>
        <li><strong>Combined Platform Health:</strong> 317 Flutter tests passing + 79 Go tests passing + 0 compiler warnings.</li>
      </ul>
    </div>
  </div>

  <div class="script-box" style="margin-top: 10px;">
    <div class="script-box-header">
      <span class="minute-title">📋 Avinash's Quick Reference Pocket Card</span>
      <span class="badge badge-coral">Code & Files</span>
    </div>
    <div style="font-size: 8pt; line-height: 1.4; color: #334155;">
      • <strong>Lasso Engine:</strong> <span class="code-pill">lib/features/gameplay/polygon_enclosure_engine.dart</span><br>
      • <strong>Shoelace Geodesy:</strong> <span class="code-pill">backend/internal/geo/shoelace.go</span><br>
      • <strong>Donut Hole Classifier:</strong> <span class="code-pill">lib/features/gameplay/donut_hole_classifier.dart</span><br>
      • <strong>Golden Test Vectors:</strong> <span class="code-pill">test_fixtures/golden_valid_loop.json</span> (15 fixtures total)<br>
      • <strong>Parity Boundary:</strong> Area discrepancy strictly &lt; 0.5% across all golden cases.
    </div>
  </div>

  <!-- PAGE BREAK -->
  <div class="page-break"></div>

  <!-- PAGE 3: TOP 4 EXAMINER VIVA DEFENSE QUESTIONS -->
  <div class="header-bar">
    <div class="header-left">
      <h1>AVINASH — Examiner Viva Defense Cheat Sheet</h1>
      <div class="sub">Top 4 killer examiner questions with rapid 15-second oral defenses</div>
    </div>
    <div class="header-right">
      <span class="badge badge-coral">Examiner Defense</span>
    </div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q1: What is the time complexity of the Lasso Loop Closure detection algorithm?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "Naive intersection testing is $O(N^2)$, which freezes phones with thousands of waypoints. We optimize it to $O(M)$ by only testing the latest GPS segment against historical segments within our 25-meter bounding box. This reduces candidate checks to fewer than 20 segments, running in under 0.2 milliseconds at 60 FPS."</div>
    <div class="viva-proof">📁 Implemented in: <code>lib/features/gameplay/polygon_enclosure_engine.dart</code></div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q2: Why does the Planar Shoelace formula work on Earth's curved spherical surface?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "Because human athletic runs are localized ($&lt; 5\text{ km}$ across), Earth's curvature error is negligible (&lt;0.2%) when longitude is scaled by the cosine of the mean latitude. Across our 15 golden fixtures, the area difference between client Shoelace and server PostGIS ellipsoidal geodesics is proven to stay strictly below 0.5%."</div>
    <div class="viva-proof">📁 Implemented in: <code>backend/internal/geo/shoelace.go</code></div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q3: How does the Jordan Curve Theorem work in your Ray-Casting Donut Hole Classifier?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "The Jordan Curve Theorem proves any closed planar loop divides space into inside and outside. We cast a semi-infinite horizontal ray from a candidate interior point. If it crosses the polygon boundary an odd number of times, the point is inside; an even count means outside. This allows us to exclude lakes and buildings from territory claims."</div>
    <div class="viva-proof">📁 Implemented in: <code>lib/features/gameplay/donut_hole_classifier.dart</code></div>
  </div>

  <div class="viva-box">
    <div class="viva-q">Q4: How did you structure the software documentation and cross-platform verification fixtures?</div>
    <div class="viva-a"><strong>15-Second Defense:</strong> "I structured the documentation into clear SRS specifications, architectural data flows, and 15 standardized JSON golden test fixtures. Both our Dart and Go test suites ingest these identical JSON files, ensuring that any algorithmic change in Go or Flutter is verified against the same ground truth."</div>
    <div class="viva-proof">📁 Implemented in: <code>test_fixtures/</code> & <code>docs/VERIFICATION.md</code></div>
  </div>

  <div class="sign-box">
    <div class="sign-line">Candidate Signature<br><strong>AVINASH</strong></div>
    <div class="sign-line">Internal Project Guide<br>Dept. of CSE</div>
    <div class="sign-line">External Viva Examiner<br>University Board</div>
  </div>

</body>
</html>
"""
    return content.replace("__CSS__", SHARED_CSS)

def compile_pdf(html_path: Path, pdf_path: Path):
    cmd = [
        EDGE_PATH,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        html_path.as_uri()
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0 or not pdf_path.exists():
        print(f"Error compiling {pdf_path.name}")
        return False
    size_kb = pdf_path.stat().st_size / 1024
    print(f"SUCCESS: {pdf_path.name} ({size_kb:.1f} KB)")
    return True

def main():
    print("=" * 70)
    print("GENERATING 3-MINUTE CONCISE COLLEGE PRESENTATION SCRIPTS")
    print("=" * 70)

    scripts = [
        ("AYUSH_3Min_Presentation_Script.html", get_ayush_3min_html(), "AYUSH_3Min_Presentation_Script.pdf"),
        ("GURUDUTT_3Min_Presentation_Script.html", get_gurudutt_3min_html(), "GURUDUTT_3Min_Presentation_Script.pdf"),
        ("AVINASH_3Min_Presentation_Script.html", get_avinash_3min_html(), "AVINASH_3Min_Presentation_Script.pdf"),
    ]

    for html_name, html_content, pdf_name in scripts:
        html_file = DOSSIER_DIR / html_name
        html_file.write_text(html_content, encoding="utf-8")
        print(f"Wrote HTML: {html_file.name}")

        # Compile to root
        root_pdf = BASE_DIR / pdf_name
        compile_pdf(html_file, root_pdf)

        # Copy to Desktop folder and Downloads
        subprocess.run(["powershell", "-Command", f"Copy-Item '{root_pdf}' -Destination '{DESKTOP_DIR}'"])
        subprocess.run(["powershell", "-Command", f"Copy-Item '{root_pdf}' -Destination '{DOWNLOADS_DIR}'"])

    print("\n" + "=" * 70)
    print("ALL 3-MINUTE PRESENTATION SCRIPTS GENERATED & COPIED TO DESKTOP AND DOWNLOADS!")
    print("=" * 70)

if __name__ == "__main__":
    main()
