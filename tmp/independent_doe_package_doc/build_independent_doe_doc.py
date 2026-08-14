from pathlib import Path
import csv
import shutil
import sys

from docx import Document
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor

sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(r"D:\work\git_share\laser_sim")
PKG = ROOT / "deliverables" / "INDEPENDENT_RELIEF_DOE_355nm_package"
REFERENCE = ROOT / "deliverables" / "HOLOOR_CBSM_LINE_355nm_package" / "HOLOOR_355nm准直线光技术说明.docx"
FINAL = PKG / "01_technical_document" / "355nm独立32级浮雕DOE线光技术说明.docx"
RESULTS = PKG / "04_simulation_results" / "matlab_R2019b"
FAB = PKG / "03_fabrication_data"
SKILL_SCRIPTS = Path(r"C:\Users\wufan\.codex\plugins\cache\openai-primary-runtime\documents\26.812.11052\skills\documents\scripts")
sys.path.insert(0, str(SKILL_SCRIPTS))
from table_geometry import apply_table_geometry, column_widths_from_weights


def clear_body(doc):
    body = doc._element.body
    for child in list(body):
        if child.tag != qn("w:sectPr"):
            body.remove(child)


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_text(cell, text, bold=False, color=None, size=9.2, align=None):
    cell.text = ""
    p = cell.paragraphs[0]
    if align is not None:
        p.alignment = align
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.05
    run = p.add_run(str(text))
    run.font.name = "微软雅黑"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "微软雅黑")
    run.font.size = Pt(size)
    run.bold = bold
    if color:
        run.font.color.rgb = RGBColor(*color)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def add_table(doc, headers, rows, weights, center_cols=()):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.autofit = False
    for i, head in enumerate(headers):
        set_cell_shading(table.rows[0].cells[i], "2E74B5")
        set_cell_text(table.rows[0].cells[i], head, bold=True,
                      color=(255, 255, 255), size=9.5,
                      align=WD_ALIGN_PARAGRAPH.CENTER)
    set_repeat_table_header(table.rows[0])
    for r_index, row_values in enumerate(rows):
        row = table.add_row()
        for c_index, value in enumerate(row_values):
            if r_index % 2 == 1:
                set_cell_shading(row.cells[c_index], "F3F7FA")
            align = WD_ALIGN_PARAGRAPH.CENTER if c_index in center_cols else WD_ALIGN_PARAGRAPH.LEFT
            set_cell_text(row.cells[c_index], value, align=align)
    widths = column_widths_from_weights(weights, 9360)
    apply_table_geometry(table, widths, table_width_dxa=9360, indent_dxa=120,
                         cell_margins_dxa={"top": 85, "bottom": 85,
                                           "start": 120, "end": 120})
    after = doc.add_paragraph()
    after.paragraph_format.space_after = Pt(2)
    return table


def add_lead(doc, label, text):
    p = doc.add_paragraph(style="Normal")
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(10)
    p.paragraph_format.left_indent = Inches(0.12)
    p.paragraph_format.right_indent = Inches(0.08)
    p.paragraph_format.keep_together = True
    p_pr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), "EAF3F8")
    p_pr.append(shd)
    borders = OxmlElement("w:pBdr")
    left = OxmlElement("w:left")
    left.set(qn("w:val"), "single")
    left.set(qn("w:sz"), "18")
    left.set(qn("w:space"), "8")
    left.set(qn("w:color"), "2E74B5")
    borders.append(left)
    p_pr.append(borders)
    r1 = p.add_run(label + "  ")
    r1.bold = True
    r1.font.color.rgb = RGBColor(31, 78, 121)
    p.add_run(text)
    return p


def add_formula(doc, latex):
    latex = latex.replace("\\\\", "\\")
    p = doc.add_paragraph(style="Normal")
    p.paragraph_format.left_indent = Inches(0.25)
    p.paragraph_format.right_indent = Inches(0.15)
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(7)
    p.paragraph_format.keep_together = True
    p_pr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), "F5F7FA")
    p_pr.append(shd)
    run = p.add_run("LaTeX: " + latex)
    run.font.name = "Consolas"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Consolas")
    run.font.size = Pt(9.2)
    run.font.color.rgb = RGBColor(47, 62, 70)
    return p


def add_code(doc, code):
    p = doc.add_paragraph(style="Normal")
    p.paragraph_format.left_indent = Inches(0.25)
    p.paragraph_format.right_indent = Inches(0.10)
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(8)
    p.paragraph_format.keep_together = True
    p_pr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), "F2F2F2")
    p_pr.append(shd)
    run = p.add_run(code)
    run.font.name = "Consolas"
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Consolas")
    run.font.size = Pt(8.7)
    return p


def add_bullet(doc, text, numbered=False):
    style = "List Number" if numbered else "List Bullet"
    p = doc.add_paragraph(text, style=style)
    p.paragraph_format.space_after = Pt(4)
    return p


def add_figure(doc, path, caption, width=6.25):
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(path)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.keep_with_next = True
    run = p.add_run()
    shape = run.add_picture(str(path), width=Inches(width))
    doc_pr = shape._inline.docPr
    doc_pr.set("descr", caption)
    cap = doc.add_paragraph(caption, style="Caption")
    cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap.paragraph_format.space_after = Pt(8)
    cap.paragraph_format.keep_with_next = False


def read_csv(path):
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


FINAL.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(REFERENCE, FINAL)
doc = Document(FINAL)
clear_body(doc)

doc.core_properties.title = "355 nm独立32级浮雕DOE线光技术说明"
doc.core_properties.subject = "双片熔融石英多级浮雕DOE设计、加工与MATLAB R2019b验证"
doc.core_properties.keywords = "355 nm, DOE, relief, fused silica, MATLAB R2019b, coherent propagation"
doc.core_properties.comments = "独立设计；不含厂商专有相位。"

title = doc.add_paragraph("355 nm 独立32级浮雕DOE线光技术说明", style="Title")
title.paragraph_format.keep_with_next = True
subtitle = doc.add_paragraph(
    "双片熔融石英相位整形 · X=1.5 mm近似平行Top-Hat · Y=1.0 µm聚焦 · MATLAB R2019b",
    style="Subtitle",
)
add_lead(doc, "设计结论", "量化后的实际浮雕相位已直接进入相干角谱传播。最终全1/e²尺寸为X=1.533032 mm、Y=1.000000 µm；X中央固定1.35 mm区域的Imin/Imax均匀性为85.388434%。X平均倾角4.437530 µrad、曲率边缘斜率16.117134 µrad。该结果是当前100 mm DOE间距、5 µm最小特征和50 mm最大尺寸约束下冻结的最佳结果，但没有达到原90%均匀性门槛。")

doc.add_heading("方案介绍", level=1)
doc.add_paragraph(
    "本方案采用两片一维多级浮雕DOE实现355 nm高斯光束到X向线形平顶光的能量重分配和波前展平。DOE1负责强度映射，DOE2位于100 mm后并补偿实际残余相位。两片结构都只沿X变化、沿Y等高延伸；它们共同形成近似准直的X向输出，不能只加工或安装其中一片。"
)
doc.add_paragraph(
    "DOE之后不再对X扩束或压缩。后级YBE1/YBE2只扩展Y，末片YFL仅在Y方向具有fY=100 mm光焦度，在X方向fX=∞。因此目标面同时获得约1.5 mm的近似平行X线光和1.0 µm的Y焦斑。"
)

doc.add_heading("1. 需求与设计输入", level=1)
requirements = [
    ("光源", "波长", "355 nm", "全部材料、镀膜和传播按355 nm"),
    ("光源", "相干性", "完全相干CW单模", "用单一确定性复电场传播"),
    ("光源", "束腰位置", "激光出口z=0", "初始波前平坦，R=∞"),
    ("光源", "束腰直径", "Dx=1.0 mm；Dy=1.1 mm", "全1/e²强度直径，短轴沿X"),
    ("光源", "M²", "M²X=M²Y=1.2", "实际测量值"),
    ("目标", "X尺寸", "1.5 mm", "全1/e²宽度，近似平行"),
    ("目标", "Y尺寸", "1.0 µm", "全1/e²焦斑宽度"),
    ("目标", "工作距离", "100 mm", "YFL至目标面"),
    ("DOE", "基底", "熔融石英", "n(355 nm)=1.476071880"),
    ("DOE", "结构", "两片、32级", "DOE1映射，DOE2展平相位"),
    ("验收", "均匀性", "Imin/Imax≥90%", "固定中央1.35 mm；当前最佳为85.388434%"),
]
add_table(doc, ["类别", "参数", "设计值/约束", "定义"], requirements,
          [1.05, 1.25, 1.7, 2.8], center_cols=(0, 1, 2))

doc.add_heading("2. 光学系统方案", level=1)
doc.add_heading("2.1 功能链", level=2)
for text in [
    "SBE1/SBE2是激光后的第一组元件，也是唯一圆对称扩束组，将X/Y共同扩束。",
    "DOE1/DOE2只对X复场进行强度映射和相位展平，Y不由DOE聚焦。",
    "YBE1/YBE2只扩展Y光束，为100 mm工作距离的1.0 µm焦斑提供所需入射口径。",
    "YFL只对Y聚焦，X方向fX=∞；DOE之后所有有光焦度元件在X模型中均为恒等算子。",
]:
    add_bullet(doc, text)

layout_rows = []
description_zh = {
    "LASER": "355 nm完全相干CW束腰；Dx=Dy=1.0 mm，M²X=M²Y=1.2",
    "SBE1": "第一元件；圆对称负扩束镜",
    "SBE2": "圆对称正扩束镜",
    "DOE1": "独立浮雕DOE1：能量映射",
    "DOE2": "独立浮雕DOE2：相位展平",
    "YBE1": "Y向负柱面扩束镜",
    "YBE2": "Y向正柱面扩束镜",
    "CXC1": "X向正柱面无焦压缩镜",
    "CXC2": "X向负柱面无焦压缩镜",
    "YFL": "末片：只对Y聚焦；X光焦度为0",
    "TARGET": "X约1.5 mm近似平行；Y聚焦1.0 µm",
}
for row in read_csv(RESULTS / "independent_relief_doe_optical_layout.csv"):
    fx = "∞" if row["fX"] == "Inf" else f'{float(row["fX"]):.3g}'
    fy = "∞" if row["fY"] == "Inf" else f'{float(row["fY"]):.4g}'
    layout_rows.append((row["ids"], f'{float(row["z"]):.1f}', row["axisPower"],
                        f"fX={fx}; fY={fy}", description_zh[row["ids"]]))
doc.add_heading("2.2 元件位置与作用轴", level=2)
add_table(doc, ["ID", "Z/mm", "作用轴", "焦距/功能", "说明"], layout_rows,
          [0.8, 0.8, 0.85, 1.3, 3.0], center_cols=(0, 1, 2, 3))

doc.add_heading("3. XZ与YZ光路图", level=1)
doc.add_heading("3.1 XZ平面：X向近似平行", level=2)
add_figure(doc, RESULTS / "independent_relief_doe_xz_optical_path.png",
           "图1  独立浮雕DOE方案XZ光路。YFL在X方向为零光焦度。")
doc.add_paragraph(
    "XZ图中Y向专用元件以虚线表示。DOE之后X不再经过有光焦度的元件；z=570 mm的YFL不会使X会聚，目标面位于z=670 mm。"
)
doc.add_heading("3.2 YZ平面：100 mm工作距离聚焦", level=2)
add_figure(doc, RESULTS / "independent_relief_doe_yz_optical_path.png",
           "图2  独立浮雕DOE方案YZ光路。YFL在100 mm后形成1.0 µm焦斑。")

doc.add_heading("4. 激光源与相干传播模型", level=1)
doc.add_heading("4.1 束腰复电场", level=2)
doc.add_paragraph(
    "激光出口被确定为束腰面，采用连续、单模、完全相干的确定性复电场。初始场不叠加随机相位，X/Y振幅均满足高斯束腰定义："
)
add_formula(doc, r"U_0(x,y)=U_p\exp\!\left[-\frac{x^2}{w_{0x}^2}-\frac{y^2}{w_{0y}^2}\right],\qquad I_0=|U_0|^2")
doc.add_paragraph("M²=1.2通过广义q参数进入瑞利长度、发散角、束宽和曲率的传播：")
add_formula(doc, r"z_R=\frac{\pi w_0^2}{M^2\lambda},\qquad \theta_{1/2}=\frac{M^2\lambda}{\pi w_0},\qquad q_0=i z_R")
doc.add_paragraph("当前1.0 mm全1/e²束腰对应全发散角0.542400 mrad、瑞利长度1843.658 mm。")

doc.add_heading("4.2 相干角谱传播", level=2)
doc.add_paragraph("所有X向DOE和后级透镜都在同一复场中连续传播，因此保留激光相干性造成的相位积累、干涉和衍射：")
add_formula(doc, r"U(x,z)=\mathcal{F}^{-1}\!\left\{\mathcal{F}[U(x,0)]H(f_x;z)\right\}")
add_formula(doc, r"H(f_x;z)=\exp\!\left[ikz\sqrt{1-\lambda^2 f_x^2}\right],\qquad k=\frac{2\pi}{\lambda}")
doc.add_paragraph("薄透镜用二次相位描述，而不是仅用几何光线改变束宽：")
add_formula(doc, r"t_L(x)=\exp\!\left[-i\frac{kx^2}{2f_x}\right]")

doc.add_heading("5. 双片浮雕DOE设计原理", level=1)
doc.add_heading("5.1 DOE1能量映射", level=2)
doc.add_paragraph(
    "DOE1的初值由累计功率守恒建立。令输入坐标为ξ、目标坐标为T(ξ)，输入高斯与目标超高斯在对应坐标左侧的归一化累计功率相等："
)
add_formula(doc, r"\frac{\int_{-\infty}^{\xi}I_{in}(s)ds}{\int_{-\infty}^{\infty}I_{in}(s)ds}=\frac{\int_{-D/2}^{T(\xi)}I_{TH}(u)du}{\int_{-D/2}^{D/2}I_{TH}(u)du}")
doc.add_paragraph("目标振幅采用m=100超高斯；其设计宽度1.54 mm略大于1.5 mm名义值，以优化固定中央1.35 mm区域的均匀性：")
add_formula(doc, r"A_{TH}(x)=A_p\exp\!\left[-\left|\frac{x}{D/2}\right|^{100}\right],\qquad D=1.54\ \mathrm{mm}")
doc.add_paragraph("两相位面相距L=100 mm，第一相位梯度产生将ξ映射到T(ξ)的局部偏转：")
add_formula(doc, r"\frac{d\phi_1}{d\xi}\approx k\sin\!\left[\tan^{-1}\!\frac{T(\xi)-\xi}{L}\right]")

doc.add_heading("5.2 双平面交替投影与DOE2", level=2)
doc.add_paragraph(
    "以能量映射相位为初值，先进行200次连续双平面交替投影和120次单片制造量化细化，再进行最多600次双片联合量化优化。在DOE1面保持实际输入振幅，在DOE2和目标面施加所需振幅约束，同时保留传播所得相位。由于量化迭代并非单调，程序在满足宽度、倾角和曲率约束时锁存历史最高均匀性；本次最佳加工相位出现在第470次联合迭代。"
)
add_formula(doc, r"U_2^-=\mathcal{P}_{L}\{U_{in}\exp(i\phi_1)\},\qquad \phi_2(x)=-\arg[U_2^-(x)]")
add_formula(doc, r"U_{out}=U_2^-\exp(i\phi_2)")
add_lead(doc, "关键边界", "本结果依赖两片独立相位面。DOE2不是可省略的保护片；若只加工DOE1，DOE2面残余相位不会被抵消，目标面宽度、均匀度和平行度都不再成立。")

doc.add_heading("5.3 相位到熔融石英浮雕", level=2)
doc.add_paragraph("相位通过透明基底的局部光程差转化为浮雕高度：")
add_formula(doc, r"\phi_{DOE}(x)=\frac{2\pi}{\lambda}[n(\lambda)-1]h(x)\pmod{2\pi}")
add_formula(doc, r"h_{2\pi}=\frac{\lambda}{n-1}=0.745685714\ \mathrm{\mu m}")
doc.add_paragraph(
    "连续相位先按实际横向加工单元做圆周平均保持，再量化到32级。程序最后一次传播使用量化后相位，而不是连续理想相位，因此最终二维强度已经包含台阶相位和有限横向单元的影响。"
)
add_formula(doc, r"\phi_q(x)=\frac{2\pi}{32}\operatorname{round}\!\left[\frac{32\phi(x)}{2\pi}\right],\qquad h_q=\frac{\phi_q}{2\pi}h_{2\pi}")

doc.add_heading("6. 浮雕加工定义", level=1)
fab_rows = []
fab_name_zh = {
    "Material": "材料",
    "Refractive index at 355 nm": "355 nm折射率",
    "Clear aperture": "通光口径",
    "Quantization levels": "相位级数",
    "Binary mask count": "二进制掩模数",
    "Requested minimum lateral feature": "请求最小横向特征",
    "Actual X cell pitch": "实际X单元节距",
    "Patterned X width": "有效图形宽度",
    "2pi relief depth": "理论2π浮雕深度",
    "Relief height step": "单级高度步长",
    "Maximum remaining relief height": "最大保留浮雕高度",
    "Mask 1 etch depth": "掩模1刻蚀深度",
    "Mask 2 etch depth": "掩模2刻蚀深度",
    "Mask 3 etch depth": "掩模3刻蚀深度",
    "Mask 4 etch depth": "掩模4刻蚀深度",
    "Mask 5 etch depth": "掩模5刻蚀深度",
}
for row in read_csv(FAB / "doe_fabrication_summary.csv"):
    name = row["doeParameter"]
    value = row["doeValue"]
    unit = row["doeUnit"]
    if name in {
        "Material", "Refractive index at 355 nm", "Clear aperture",
        "Quantization levels", "Binary mask count",
        "Requested minimum lateral feature", "Actual X cell pitch",
        "Patterned X width", "2pi relief depth", "Relief height step",
        "Maximum remaining relief height", "Mask 1 etch depth",
        "Mask 2 etch depth", "Mask 3 etch depth", "Mask 4 etch depth",
        "Mask 5 etch depth",
    }:
        if name == "Material":
            value = "熔融石英（Malitson Sellmeier）"
        else:
            try:
                value = f"{float(value):.9g}"
            except ValueError:
                pass
        unit = unit.replace("um", "µm")
        fab_rows.append((fab_name_zh[name], value, unit))
add_table(doc, ["加工参数", "数值", "单位"], fab_rows, [2.9, 1.6, 0.9], center_cols=(1, 2))

doc.add_heading("6.1 高度基准与掩模极性", level=2)
for text in [
    "relief profile/cells文件中的remainingReliefHeight是相对最深参考面的保留玻璃高度。",
    "etchDepthFromOriginal = maximumReliefHeight - remainingReliefHeight。",
    "二进制掩模CSV中1表示开窗/曝光并执行该层刻蚀，0表示保护。",
    "五层刻蚀深度按二进制权重递增；加工方必须结合正/负胶和掩模正/负片确认极性。",
    "中心8 mm为有效浮雕图形区；50 mm最大通光尺寸内的外侧区域保持未刻蚀平面。",
]:
    add_bullet(doc, text)

add_figure(doc, FAB / "doe_relief_and_lithography_design.png",
           "图3  DOE1与DOE2连续相位、32级制造相位及保留浮雕高度。", width=6.3)
add_figure(doc, FAB / "doe_binary_lithography_mask_preview.png",
           "图4  两片DOE的五层二进制刻蚀掩模预览；白色为开窗刻蚀。", width=6.3)

doc.add_heading("6.2 加工数据文件", level=2)
for text in [
    "doe1_relief_cells.csv / doe2_relief_cells.csv：可合并加工区间、级次、保留高度和总刻蚀深度。",
    "doe1_relief_profile.csv / doe2_relief_profile.csv：完整采样轮廓及连续/量化相位。",
    "doe_binary_lithography_masks.csv：DOE1/DOE2五层开窗刻蚀数据。",
    "doe_fabrication_instructions.txt：高度基准、掩模极性、材料和逐层刻蚀深度说明。",
]:
    add_bullet(doc, text)

doc.add_heading("7. MATLAB R2019b程序过程", level=1)
doc.add_heading("7.1 主程序", level=2)
doc.add_paragraph("独立包的唯一主入口为：")
add_code(doc, "cd('<资料包>/02_matlab_code');\nresult = run_independent_relief_DOE_R2019b();")
doc.add_paragraph("主程序不调用旧HOLO/OR厂商模型，也不查找厂商相位文件。执行顺序如下：")
steps = [
    "读取independent_relief_doe_config.m并检查MATLAB版本必须为R2019b。",
    "按参考资料第7.1/7.3节验证束腰高斯振幅、强度、q参数、发散角和M²传播。",
    "建立DOE1输入复场，设计连续双平面相位并执行200次交替投影。",
    "施加最小特征保持、32级高度量化和8 mm有效图形区，再执行120次DOE1量化细化和最多600次双DOE联合优化。",
    "在满足X宽度、平均倾角和曲率约束时锁存历史最高均匀性加工相位。",
    "让量化相位通过100 mm DOE间距和目标面角谱传播；后续YBE/YFL在X方向均不施加透镜相位。",
    "独立用M²高斯q参数传播Y光路，验证YFL后100 mm的1.0 µm焦斑。",
    "输出浮雕CSV、五层掩模、二维强度、XZ/YZ光路、效率预算和验收表。",
]
for step in steps:
    add_bullet(doc, step, numbered=True)

doc.add_heading("7.2 数值网格与制造约束", level=2)
code_rows = [
    ("X传播采样数", "65,536", "提高横向单元和相位梯度分辨率"),
    ("计算窗口", "80 mm", "降低FFT周期卷绕影响"),
    ("实际X单元节距", "6.103516 µm", "向上取整，绝不低于5 µm请求值"),
    ("DOE有效图形宽度", "8 mm", "外侧保持未刻蚀，避免无能量区随机相位"),
    ("相位优化迭代", "200+120+600", "连续、单片量化及双片联合优化；最佳为联合第470次"),
    ("相位级数", "32", "直接用于最终复场传播"),
]
add_table(doc, ["项目", "设定", "作用"], code_rows, [2.0, 1.5, 3.2], center_cols=(1,))

doc.add_heading("7.3 相位和准直指标提取", level=2)
doc.add_paragraph(
    "在有效X光斑内展开相位，去除piston和平均倾角后计算相位RMS；二次项不被删除，因此有限曲率仍计入准直误差。平均倾角和曲率边缘斜率分别为："
)
add_formula(doc, r"\bar{\theta}_x=\frac{\lambda}{2\pi}a_1,\qquad R_x=\frac{\pi}{\lambda a_2},\qquad \theta_{edge}=\frac{D_X/2}{|R_x|}")
add_formula(doc, r"\sigma_{\phi}=\sqrt{\frac{1}{N}\sum_n\left[\phi(x_n)-(b_1x_n+b_0)\right]^2}")

doc.add_heading("8. 仿真结果", level=1)
add_figure(doc, RESULTS / "target_plane_2d_intensity.png",
           "图5  z=670 mm最终平面二维归一化强度；X使用量化浮雕相干传播，Y使用M²高斯焦斑。", width=6.3)
add_figure(doc, RESULTS / "phase_surrogate_intensity_angle.png",
           "图6  DOE2出口与目标面的X向强度和局部相位梯度角。", width=6.25)

acceptance_rows = []
metric_zh = {
    "First spherical expander magnification": "第一组圆对称扩束倍率",
    "X full 1/e^2 width": "X全1/e²宽度",
    "X FWHM": "X半高全宽",
    "X central-90 percent min/max uniformity": "X中央90% Imin/Imax均匀性",
    "X uniformity limit": "X均匀性门槛",
    "Y full 1/e^2 width": "Y全1/e²宽度",
    "Target mean X tilt": "目标平均X倾角",
    "Target curvature edge slope": "目标曲率边缘斜率",
    "X width change after 100 mm": "继续传播100 mm后的X宽度变化",
    "X width-change limit": "宽度变化参考值",
    "Actual relief X cell pitch": "实际浮雕X单元节距",
    "Design verification pass": "设计验证通过",
}
for row in read_csv(RESULTS / "independent_relief_doe_acceptance.csv"):
    val = float(row["value"])
    if row["metric"] == "Y full 1/e^2 width":
        val *= 1000
        unit = "µm"
    else:
        unit = row["unit"].replace("um", "µm").replace("urad", "µrad")
    formatted = f"{val:.6g}"
    acceptance_rows.append((metric_zh[row["metric"]], formatted, unit))
add_table(doc, ["验收项目", "结果", "单位"], acceptance_rows,
          [3.0, 1.55, 0.9], center_cols=(1, 2))
add_lead(doc, "验收状态", "X尺寸、Y尺寸、平均倾角和曲率边缘斜率均满足设定条件；中央90%区域均匀性为85.388434%，低于原90%门槛，因此总验收标志保持为0。该数值是用户确认按当前主配置输出的最佳结果，不能表述为达到90%。")

doc.add_heading("9. 能量效率预算", level=1)
doc.add_paragraph(
    "理想相位乘子模长为1，因此标量传播本身不吸收功率；但量化会把部分能量送入非目标衍射分量，空气/石英界面会反射，实际加工还存在散射、吸收和目标窗口外溢。32级相位的理想量化上限为："
)
add_formula(doc, r"\eta_{32}=\left[\frac{\sin(\pi/32)}{\pi/32}\right]^2=99.6791\%")
doc.add_paragraph("未镀膜单表面的法向Fresnel反射估算为：")
add_formula(doc, r"R=\left(\frac{n-1}{n+1}\right)^2=3.6967\%")
eff_rows = []
eff_item_zh = {
    "Single-DOE 32-level phase quantization": "单片DOE的32级量化",
    "Two-DOE phase quantization": "两片DOE的相位量化",
    "Single uncoated surface reflection": "单个未镀膜表面反射",
    "Four uncoated surfaces transmission": "四个未镀膜表面透射",
    "Two DOE, uncoated theoretical upper bound": "两片DOE未镀膜理论上限",
    "Two DOE, 0.5% residual-R per surface upper bound": "每面剩余反射0.5%时的两片上限",
}
eff_note_zh = {
    "Phase-level upper bound": "相位级量化上限",
    "Product of two phase-level factors": "两个量化因子的乘积",
    "Normal-incidence Fresnel estimate": "法向Fresnel估算",
    "Four air/silica interfaces": "四个空气/石英界面",
    "Excludes scatter, absorption and target spillover": "不含散射、吸收及目标外溢",
    "Requires qualified 355 nm AR coating": "要求合格的355 nm增透膜",
}
for row in read_csv(RESULTS / "efficiency_budget.csv"):
    eff_rows.append((eff_item_zh[row["item"]], f'{float(row["valuePercent"]):.4f}',
                     eff_note_zh[row["note"]]))
add_table(doc, ["效率项目", "数值/%", "说明"], eff_rows,
          [2.9, 1.0, 2.7], center_cols=(1,))
add_lead(doc, "工程建议", "两片DOE共四个空气/石英表面。未镀膜理论上限约85.46%；若355 nm增透膜做到每面残余反射≤0.5%，量化与表面反射合并上限约97.39%。最终加工验收还应测量进入目标有效区域的绝对功率，而不能用归一化强度图代替。")

doc.add_heading("10. 验收条件与工艺边界", level=1)
criteria = [
    ("输入光源", "355 nm；Dx/Dy、椭圆度、M²、束腰位置和功率与设计输入一致"),
    ("DOE配对", "DOE1和DOE2必须按标识成对安装，轴向间距100 mm，二者之间无其他元件"),
    ("方向", "浮雕条纹沿Y延伸，调制方向为X；禁止旋转90°"),
    ("X尺寸", "目标全1/e²宽度1.5 mm，建议允许±5%"),
    ("X均匀性", "固定中央1.35 mm区域Imin/Imax原门槛90%；当前冻结结果85.388434%"),
    ("Y尺寸", "目标全1/e²宽度1.0 µm，模型判据±1%"),
    ("X平行度", "平均倾角≤10 µrad；曲率边缘斜率≤50 µrad；相位RMS仅作诊断，不设硬门槛"),
    ("浮雕深度", "按每级23.302679 nm和五层名义刻蚀深度检测，工艺偏差由加工方能力确认"),
    ("表面", "确认355 nm AR膜、粗糙度、清洁度、损伤阈值和侧壁散射"),
    ("效率", "以目标有效区域绝对功率/DOE1入射功率测量，并同时记录零级光和杂散光"),
]
add_table(doc, ["验收项", "条件"], criteria, [1.55, 4.8])
doc.add_paragraph(
    "有限宽度光束必然存在衍射展开；本项目所称“X方向近似平行”是指没有由末片透镜或残余二次相位造成的显著几何会聚/发散，并以平均倾角和曲率边缘斜率验收，不要求有限孔径光束具有严格零角谱宽度。"
)

doc.add_heading("11. 模型适用范围", level=1)
for text in [
    "X和Y采用可分离模型；未模拟非零椭圆旋转导致的XY耦合。",
    "透镜按薄元件、无像差处理，空气折射率取1；未包含装调偏心、倾斜、面形和镀膜相位。",
    "效率表是量化与表面反射的工程上限，不含加工散射、材料吸收和目标区域外功率。",
    "实际投产前应对刻蚀深度误差、横向线宽偏差、两片横向/旋转/轴向误差进行公差蒙特卡洛分析。",
    "本设计完全独立，不应被表述为HOLO/OR或其他厂商的专有结构复现。",
]:
    add_bullet(doc, text)

doc.add_heading("附录A：资料包结构", level=1)
package_rows = [
    ("01_technical_document", "本Word技术说明"),
    ("02_matlab_code", "独立MATLAB R2019b主程序、配置、DOE、Y向传播和光路图代码"),
    ("03_fabrication_data", "DOE1/DOE2浮雕轮廓、区间、五层掩模和加工说明"),
    ("04_simulation_results/matlab_R2019b", "二维强度、相位、XZ/YZ、效率、验收和MAT结果"),
    ("05_references", "高斯光束参考PDF和模型说明"),
    ("README_CN.md", "运行入口、关键结果和目录说明"),
]
add_table(doc, ["目录/文件", "内容"], package_rows, [2.7, 3.7])

doc.add_heading("附录B：程序文件说明", level=1)
program_rows = [
    ("run_independent_relief_DOE_R2019b.m", "唯一主程序；运行、验收并刷新加工数据"),
    ("independent_relief_doe_config.m", "激光、光路、DOE材料、量化和验收参数唯一来源"),
    ("simulate_independent_relief_doe.m", "DOE1/DOE2设计、制造量化、相干传播和二维强度"),
    ("simulate_y_m2_gaussian_path.m", "Y向M² q参数传播和1.0 µm焦斑验证"),
    ("build_coherent_laser_waist_1d.m", "完全相干高斯束腰复场"),
    ("verify_laser_model_against_reference.m", "按参考资料验证高斯束物理定义"),
    ("plot_independent_relief_doe_paths.m", "XZ/YZ光路图和元件表"),
]
add_table(doc, ["MATLAB文件", "作用"], program_rows, [3.0, 3.4])

doc.add_heading("附录C：参考资料", level=1)
doc.add_paragraph("[1] optical_design_using_excel.pdf，第7.1节“What is a Gaussian Beam?”及第7.3节M²传播模型；随包位于05_references。")
doc.add_paragraph("[2] Malitson型熔融石英Sellmeier系数；数值系数和计算式固化于independent_relief_doe_config.m。")
doc.add_paragraph("[3] 本资料包MATLAB R2019b执行清单、doe_fabrication_summary.csv、efficiency_budget.csv和independent_relief_doe_acceptance.csv。")

doc.save(FINAL)
print(FINAL)
