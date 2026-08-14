from pathlib import Path
from zipfile import ZipFile
import sys

sys.stdout.reconfigure(encoding="utf-8")
path = Path(r"D:\work\git_share\laser_sim\deliverables\INDEPENDENT_RELIEF_DOE_355nm_package\01_technical_document\355nm独立32级浮雕DOE线光技术说明.docx")
terms = ["HOLO/OR", "HOLOOR", "holoor", "CBSM"]
with ZipFile(path) as zf:
    print("parts", len(zf.namelist()))
    for name in zf.namelist():
        try:
            text = zf.read(name).decode("utf-8")
        except Exception:
            continue
        found = [term for term in terms if term in text]
        if found:
            print(name, found)
