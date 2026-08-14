from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from xml.etree import ElementTree as ET
import shutil
import tempfile

path = Path(r"D:\work\git_share\laser_sim\deliverables\INDEPENDENT_RELIEF_DOE_355nm_package\01_technical_document\355nm独立32级浮雕DOE线光技术说明.docx")
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PR_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
IMAGE_TYPE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"

with ZipFile(path, "r") as zin:
    payload = {name: zin.read(name) for name in zin.namelist()}

doc_root = ET.fromstring(payload["word/document.xml"])
used_ids = set()
for element in doc_root.iter():
    for attr_name, attr_value in element.attrib.items():
        if attr_name.startswith("{" + R_NS + "}"):
            used_ids.add(attr_value)

rels_root = ET.fromstring(payload["word/_rels/document.xml.rels"])
remove_targets = set()
for rel in list(rels_root):
    if rel.get("Type") == IMAGE_TYPE and rel.get("Id") not in used_ids:
        target = rel.get("Target")
        if target and target.startswith("media/"):
            remove_targets.add("word/" + target)
        rels_root.remove(rel)

ET.register_namespace("", PR_NS)
payload["word/_rels/document.xml.rels"] = ET.tostring(
    rels_root, encoding="utf-8", xml_declaration=True
)
for target in remove_targets:
    payload.pop(target, None)

tmp = path.with_suffix(".cleaning.docx")
with ZipFile(tmp, "w", ZIP_DEFLATED) as zout:
    for name, data in payload.items():
        zout.writestr(name, data)
tmp.replace(path)
print(f"removed {len(remove_targets)} orphan images")
