from zipfile import ZipFile
from lxml import etree

p = r"D:\work\git_share\laser_sim\deliverables\HOLOOR_ST-426-I-Y-A_355nm技术资料包\HOLOOR_ST-426-I-Y-A_355nm线聚焦技术方案.docx"
with ZipFile(p) as z:
    root = etree.fromstring(z.read("word/document.xml"))
ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
body = root.find("w:body", ns)
for node in list(body)[-20:]:
    print(etree.QName(node).localname, repr("".join(node.itertext())[:100]), len(node.xpath('.//w:br[@w:type="page"]', namespaces=ns)))
