import os
import sys
import subprocess
from pathlib import Path

BASE_DIR = Path(__file__).parent.resolve()
EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

def compile_pdf(html_path: Path, pdf_path: Path):
    print(f"Compiling {html_path.name} -> {pdf_path.name}...")
    cmd = [
        EDGE_PATH,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path.resolve()}",
        html_path.resolve().as_uri()
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

if __name__ == "__main__":
    html_file = BASE_DIR / "study_notes_printable.html"
    pdf_file = BASE_DIR / "Territory_Runner_Study_Notes.pdf"
    
    if not html_file.exists():
        print(f"Error: {html_file} does not exist.")
        sys.exit(1)
        
    success = compile_pdf(html_file, pdf_file)
    if success:
        print(f"PDF generated successfully at: {pdf_file}")
    else:
        print("PDF compilation failed.")
        sys.exit(1)
