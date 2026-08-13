from zipfile import ZipFile
from lxml import etree

p = r"D:\work\git_share\laser_sim\deliverables\HOLOOR_ST-426-I-Y-A_355nm技术资料包\HOLOOR_ST-426-I-Y-A_355nm线聚焦技术方案.docx"
ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
with ZipFile(p) as z:
    d = etree.fromstring(z.read("word/document.xml"))
    n = etree.fromstring(z.read("word/numbering.xml"))
for pnode in d.xpath('//w:p[w:pPr/w:numPr]', namespaces=ns):
    text = ''.join(pnode.xpath('.//w:t/text()', namespaces=ns))
    num = pnode.xpath('./w:pPr/w:numPr/w:numId/@w:val', namespaces=ns)
    if text.startswith(("检查", "不装", "型号/波长")):
        print(text[:20], num)
for num in n.xpath('//w:num', namespaces=ns)[-5:]:
    print(etree.tostring(num, encoding='unicode'))
