# Template execution contract

## Reference

- Retained reference: `D:\work\git_share\laser_sim\deliverables\HOLOOR_CBSM_LINE_355nm_package\HOLOOR_355nm准直线光技术说明.docx`
- SHA-256: `54C71CAF668E8F9FACDBD9BD369F50419A8A18A51C71A5C60D008A92067DC949`
- Cached Word metadata: 13 pages, 4,627 words. One section, 138 body paragraphs, five tables, 24 embedded images.
- Structural evidence: `reference_structure.txt`, `reference_style.json`, `section_audit.py` output in this task directory.
- Rendering evidence: canonical renderer failed because LibreOffice is not installed. A read-only Microsoft Word COM export was attempted and timed out without creating a PDF. Visual page comparison is therefore unresolved and must be disclosed; structural audits and image inspection are the fallback authority.

## Page system

- US Letter portrait: 8.5 x 11 in.
- Margins: 1.0 in on every side.
- Header/footer distance: 0.4917 in.
- One section, no different-first-page behavior, no odd/even split. Header and footer contain empty styled paragraphs only.

## Typography and paragraph system

- Normal: Microsoft YaHei, 11 pt, black, 6 pt after, 1.1 line spacing.
- Title: 24 pt, color `1F4E79`, 0 pt before, 12 pt after, single spacing, keep with next.
- Subtitle: 13 pt, color `667085`, 0 pt before, 16 pt after, keep with next.
- Heading 1: 16 pt bold, color `2E74B5`, 16 pt before, 8 pt after, keep with next.
- Heading 2: 13 pt bold, color `2E74B5`, 12 pt before, 6 pt after, keep with next.
- Heading 3: 12 pt bold, color `1F4E79`, 8 pt before, 4 pt after, keep with next.
- Caption: 9 pt bold, color `4F81BD`, single spacing.
- Code/formula blocks in the source use Consolas with direct formatting; preserve this visual role for MATLAB and LaTeX display text.

## Lists and tables

- Reuse the retained `List Number` and `List Bullet` numbering definitions so wrapped lines align under item text.
- Reuse the source table visual style. Header rows use blue fill/white or dark text treatment according to the source table component, repeat on page breaks, and use vertically centered cells.
- New tables must use the source's visible grid and deliberate unequal widths. No fixed row heights.

## Components and content flow

- Opening block: title, subtitle, one blue-accent lead summary paragraph.
- Major sections: introduction; requirements; optical train; XZ/YZ diagrams; DOE principle; mathematical model; relief/fabrication design; MATLAB implementation; simulation results; efficiency; acceptance; package appendix; references.
- Figures: centered page-width images with a separate Caption paragraph immediately below.
- Formulas: explanatory prose followed by a standalone `LaTeX:` paragraph in Consolas, matching the retained document.
- Tables: input/specification matrix, functional chain, optical element table, fabrication parameters, acceptance results, execution records.

## Slot map

- Replace title/subtitle/lead with the independent DOE identity and the confirmed 1.5 mm x 1.0 um output.
- Remove all vendor product-selection, proprietary phase-interface, RFQ, and vendor-acceptance content.
- Preserve the physical optical layout but rename the two phase elements DOE1/DOE2 and describe their independent relief functions.
- Replace the old surrogate/model implementation section with the actual 65,536-point, 32-level, minimum-feature-controlled manufactured-phase propagation.
- Add manufacturing polarity, remaining-relief height, etch-depth, five-mask and efficiency sections.
- Replace all figures with the independent package's latest XZ, YZ, relief, mask, intensity and wavefront images.
- Replace appendices with the new package structure and local reference list.

## Package preservation

- Preserve from the retained copy: page geometry, styles, theme, font table, numbering, settings, headers and footers.
- Editable/rebuilt: `word/document.xml`, its image relationships, body tables, body drawings, captions, and media referenced by the new body.
- Preserve opaque parts when possible: custom XML, footnotes, endnotes and document properties. Update title/subject metadata to the independent DOE document.
- The retained source must remain byte-for-byte unchanged.

## Fidelity gates

- Page geometry and section count remain unchanged.
- Title/heading/body/caption typography remains recognizably source-derived.
- All tables have readable widths and no fixed-height clipping.
- Figure and caption remain together when possible.
- No HOLO/OR model code or proprietary-phase acceptance section remains in the new document.
- Final document opens with python-docx, passes section/style/image audits, contains all expected figures, tables and equations, and has no missing relationships.
- Visual render gate remains unavailable unless LibreOffice or a functional Word PDF export becomes available before delivery.
