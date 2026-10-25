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
@page { size: A4 portrait; margin: 12mm 14mm 12mm 14mm; }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Inter', sans-serif; color: #0f172a; line-height: 1.45; font-size: 9pt; }
.header-bar { border-bottom: 2px solid #2563eb; padding-bottom: 8px; margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center; }
.header-bar h1 { font-size: 14pt; font-weight: 800; color: #0f172a; }
.badge-timer { background: #0f172a; color: white; padding: 3px 8px; border-radius: 4px; font-family: monospace; font-size: 8pt; }
.timeline-card { border: 1px solid #cbd5e1; border-radius: 6px; padding: 10px 12px; margin-bottom: 10px; background: #ffffff; }
.timeline-hdr { display: flex; justify-content: space-between; font-weight: 700; font-size: 9pt; margin-bottom: 4px; border-bottom: 1px solid #f1f5f9; padding-bottom: 3px; }
.timeline-hdr.ayush { color: #1d4ed8; }
.timeline-hdr.guru { color: #7e22ce; }
.timeline-hdr.avi { color: #be123c; }
.handover-cue { background: #fef3c7; border-left: 3px solid #d97706; padding: 4px 8px; font-size: 8pt; margin-top: 5px; border-radius: 4px; }
table { width: 100%; border-collapse: collapse; margin-top: 8px; font-size: 8pt; }
th { background: #0f172a; color: white; padding: 5px 8px; text-align: left; }
td { border: 1px solid #e2e8f0; padding: 5px 8px; }
"""

html_team = r"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>TEAM 10-Minute Presentation Master Cheat Sheet</title>
  <style>__CSS__</style>
</head>
<body>
  <div class="header-bar">
    <div>
      <h1>TERRITORY RUNNER — 10-Minute Team Presentation Master Sheet</h1>
      <div style="font-size: 8.5pt; color: #475569;">Synchronized Speaking Schedule & Transition Handovers for College Evaluation Panel</div>
    </div>
    <div><span class="badge-timer">MAX TIME: 10:00 MIN</span></div>
  </div>

  <div class="timeline-card">
    <div class="timeline-hdr ayush">
      <span>0:00 – 3:00 (3 MINS) : AYUSH — Server-Authoritative Backend & Concurrency</span>
      <span>SPEAKER 1</span>
    </div>
    <p><strong>0:00 - 1:00 (Hook):</strong> Strava 1D passive tracks vs Territory Runner 2D organic GPS polygons. Core Rule: Mobile untrusted; Go 1.24 + PostGIS 3.4 is the single source of truth.</p>
    <p><strong>1:00 - 2:00 (Core Tech):</strong> Spatial concurrency: why OCC and Redis Redlock fail. Solution: <code>pg_advisory_xact_lock</code>. Kinematic anti-cheat speed ceilings (25 km/h run, 50 km/h bike, 4.5 m/s² accel).</p>
    <p><strong>2:00 - 3:00 (Integrity & Handover):</strong> Idempotency keys prevent double claims. 79 Go tests, sub-35ms p95 latency, Docker containerization.</p>
    <div class="handover-cue">🗣️ <strong>Ayush's Handover Words:</strong> "Now, I hand over to my teammate Gurudutt, who will present the mobile UI design and athletic design system."</div>
  </div>

  <div class="timeline-card">
    <div class="timeline-hdr guru">
      <span>3:00 – 6:00 (3 MINS) : GURUDUTT — Mobile UI/UX Design & Athletic Ergonomics</span>
      <span>SPEAKER 2</span>
    </div>
    <p><strong>3:00 - 4:00 (Design Philosophy):</strong> Outdoor runner constraints: direct noon sunlight glare & sweat/bouncing hands. Athletic Minimal design system: "Ink and Pacer Blue".</p>
    <p><strong>4:00 - 5:00 (Map HUD & Hold Gesture):</strong> Carbon `#090B0F` (anti-glare, OLED battery saver) + Pacer Blue `#4C8DFF` (conquest). 60 FPS vector map using Flutter <code>RepaintBoundary</code>. 1400ms Hold-to-Finish circular gesture with 350ms haptic pulses.</p>
    <p><strong>5:00 - 6:00 (Feedback & Handover):</strong> AppToast notification framework for reconciliation & GPS warnings. 317 Flutter tests, zero layout overflows, responsive across all screen densities.</p>
    <div class="handover-cue">🗣️ <strong>Gurudutt's Handover Words:</strong> "Now, I pass the floor to my teammate Avinash, who will present our computational geometry algorithms, loop detection, and project documentation."</div>
  </div>

  <div class="timeline-card">
    <div class="timeline-hdr avi">
      <span>6:00 – 9:00 (3 MINS) : AVINASH — Computational Geometry, Parity & Master Documentation</span>
      <span>SPEAKER 3</span>
    </div>
    <p><strong>6:00 - 7:00 (Lasso Closure):</strong> Organic loops cross track breadcrumbs. Lasso Closure Algorithm: 150m minimum guard, 25m snap buffer, line segment intersection math, Clipper2 polygon slicing.</p>
    <p><strong>7:00 - 8:00 (Parity & Donut Holes):</strong> Scaled planar Shoelace on Flutter vs PostGIS <code>ST_Area</code>: &lt; 0.5% area discrepancy proven across 15 golden fixtures. Ray-Casting Donut Classifier (Jordan Curve Theorem) to exclude lakes.</p>
    <p><strong>8:00 - 9:00 (Documentation & Close):</strong> Master SRS, architectural sequence flows, API contracts, and cross-platform verification. Inviting examiner questions.</p>
    <div class="handover-cue">🗣️ <strong>Avinash's Closing Words:</strong> "In conclusion, Territory Runner unites server authority, athletic UI, and geometric rigor. My teammates Ayush, Gurudutt, and I are now ready for your questions."</div>
  </div>

  <div class="timeline-card">
    <div class="timeline-hdr" style="color: #059669;">
      <span>9:00 – 10:00 (1 MIN) : INTEGRATED LIVE DEMO & TEAM TRANSITION TO VIVA</span>
      <span>ALL THREE</span>
    </div>
    <p>• Show phone running the app in dark mode, trigger an instant loop closure on the map, show 317 Flutter + 79 Go tests passing badge.</p>
  </div>

  <div style="margin-top: 10px;">
    <strong>Quick Viva Responsibility Routing (Who Answers What):</strong>
    <table>
      <thead>
        <tr><th>Topic Asked by Examiner</th><th>Answering Member</th><th>Core Keywords to Say in First 5 Seconds</th></tr>
      </thead>
      <tbody>
        <tr><td>Concurrency, DB, Deadlocks, Redis</td><td><strong>AYUSH</strong></td><td>"pg_advisory_xact_lock inside PostgreSQL kernel, auto-released on commit/rollback."</td></tr>
        <tr><td>Anti-Cheat, Vehicle Spoofing, GPS Jumps</td><td><strong>AYUSH</strong></td><td>"Kinematic sliding window, 25 km/h run ceiling, 4.5 m/s² acceleration ceiling."</td></tr>
        <tr><td>UI Glare, OLED Battery, Color Tokens</td><td><strong>GURUDUTT</strong></td><td>"Ink #090B0F carbon canvas, Pacer Blue #4C8DFF, high-contrast sunlight readability."</td></tr>
        <tr><td>Accidental Button Touches, Map 60 FPS</td><td><strong>GURUDUTT</strong></td><td>"1400ms hold-to-finish with haptic ticks; Flutter RepaintBoundary layer isolation."</td></tr>
        <tr><td>Loop Detection, Self-Intersection, Clipper2</td><td><strong>AVINASH</strong></td><td>"Lasso proximity snapping (25m buffer), segment line intersection math, tail pruning."</td></tr>
        <tr><td>Shoelace Parity, Geodesics, Donut Holes</td><td><strong>AVINASH</strong></td><td>"Scaled planar Shoelace matching PostGIS ST_Area within 0.5%; Jordan Curve ray-casting."</td></tr>
      </tbody>
    </table>
  </div>
</body>
</html>
""".replace("__CSS__", SHARED_CSS)

def compile_pdf(html_path, pdf_path):
    cmd = [EDGE_PATH, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", f"--print-to-pdf={pdf_path}", html_path.as_uri()]
    subprocess.run(cmd, capture_output=True, text=True)

html_file = DOSSIER_DIR / "TEAM_10Min_Master_Presentation_Script.html"
html_file.write_text(html_team, encoding="utf-8")
root_pdf = BASE_DIR / "TEAM_10Min_Master_Presentation_Script.pdf"
compile_pdf(html_file, root_pdf)
subprocess.run(["powershell", "-Command", f"Copy-Item '{root_pdf}' -Destination '{DESKTOP_DIR}'"])
subprocess.run(["powershell", "-Command", f"Copy-Item '{root_pdf}' -Destination '{DOWNLOADS_DIR}'"])
print("TEAM_10Min_Master_Presentation_Script.pdf generated successfully!")
