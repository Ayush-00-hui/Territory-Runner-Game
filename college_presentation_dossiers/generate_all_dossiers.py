import os
import sys
import subprocess
from pathlib import Path

# Add current directory to path
dossier_dir = Path(__file__).parent.resolve()
sys.path.insert(0, str(dossier_dir))

from gen_ayush import get_ayush_html
from gen_gurudutt import get_gurudutt_html
from gen_avinash import get_avinash_html
from gen_master import get_master_html

BASE_DIR = Path(r"c:\Users\AYUSH\Desktop\territory_runner")
EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

def compile_pdf(html_path: Path, pdf_path: Path):
    print(f"Compiling {html_path.name} -> {pdf_path.name}...")
    cmd = [
        EDGE_PATH,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        html_path.as_uri()
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error compiling {html_path.name}: {result.stderr}")
        return False
    if not pdf_path.exists():
        print(f"Failed to create {pdf_path}")
        return False
    size_kb = pdf_path.stat().st_size / 1024
    print(f"SUCCESS: {pdf_path.name} ({size_kb:.1f} KB)")
    return True

def main():
    print("=" * 70)
    print("TERRITORY RUNNER — COLLEGE DEFENSE DOSSIER & PDF GENERATOR")
    print("=" * 70)

    # 1. Generate HTML files
    docs = [
        ("AYUSH_Territory_Runner_College_Defense.html", get_ayush_html(), "AYUSH_Territory_Runner_College_Defense.pdf"),
        ("GURUDUTT_Territory_Runner_College_Defense.html", get_gurudutt_html(), "GURUDUTT_Territory_Runner_College_Defense.pdf"),
        ("AVINASH_Territory_Runner_College_Defense.html", get_avinash_html(), "AVINASH_Territory_Runner_College_Defense.pdf"),
        ("TERRITORY_RUNNER_TEAM_WORK_DIVISION.html", get_master_html(), "TERRITORY_RUNNER_TEAM_WORK_DIVISION.pdf"),
    ]

    for html_name, html_content, pdf_name in docs:
        html_file = dossier_dir / html_name
        html_file.write_text(html_content, encoding="utf-8")
        print(f"Wrote HTML: {html_file.name}")

        # PDF output in workspace root for easy access
        pdf_file = BASE_DIR / pdf_name
        success = compile_pdf(html_file, pdf_file)
        if not success:
            print(f"FAILED on {pdf_name}")
            sys.exit(1)

    print("\n" + "=" * 70)
    print("ALL 4 COLLEGE DEFENSE DOSSIER PDFS GENERATED SUCCESSFULLY!")
    print("=" * 70)
    for _, _, pdf_name in docs:
        p = BASE_DIR / pdf_name
        print(f" • {p.name} [{p.stat().st_size / 1024:.1f} KB]")

if __name__ == "__main__":
    main()
