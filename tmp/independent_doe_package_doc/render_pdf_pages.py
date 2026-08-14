from pathlib import Path
import fitz

pdf_path = Path(r"D:\work\git_share\laser_sim\tmp\independent_doe_package_doc\final_word_render.pdf")
out_dir = pdf_path.parent / "final_word_pages"
out_dir.mkdir(exist_ok=True)
doc = fitz.open(pdf_path)
matrix = fitz.Matrix(1.65, 1.65)
for index, page in enumerate(doc):
    pix = page.get_pixmap(matrix=matrix, alpha=False)
    pix.save(out_dir / f"page-{index + 1:02d}.png")
print(len(doc))
