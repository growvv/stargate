# -*- coding: utf-8 -*-
"""Update Word fields/TOC, compact TOC styles, and export PDF."""
import os
import win32com.client as win32

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(BASE))
DOCX = os.path.join(ROOT, 'submission', 'StarGate_项目文档.docx')
PDF = os.path.join(ROOT, 'submission', 'StarGate_项目文档.pdf')

word = win32.DispatchEx('Word.Application')
word.Visible = False
word.DisplayAlerts = 0
try:
    doc = word.Documents.Open(DOCX, ReadOnly=False)
    # 1) refresh all fields so the TOC has entries/pages
    doc.Fields.Update()
    for toc in doc.TablesOfContents:
        toc.Update()

    # 2) compact the TOC styles so it fits two pages
    for name, size, before, after in [('TOC 1', 10.5, 3, 1), ('TOC 2', 10, 0, 0)]:
        try:
            st = doc.Styles(name)
            st.Font.Size = size
            st.ParagraphFormat.SpaceBefore = before
            st.ParagraphFormat.SpaceAfter = after
            st.ParagraphFormat.LineSpacingRule = 0  # single
        except Exception as exc:
            print('style skip', name, exc)

    for toc in doc.TablesOfContents:
        toc.Update()
    doc.Repaginate()

    # 3) report page count and refresh headers/footers
    for sec in doc.Sections:
        sec.Headers(1).Range.Fields.Update()
        sec.Footers(1).Range.Fields.Update()

    doc.Save()
    print('pages:', doc.ComputeStatistics(2))  # wdStatisticPages
    doc.ExportAsFixedFormat(
        OutputFileName=PDF,
        ExportFormat=17,          # wdExportFormatPDF
        OpenAfterExport=False,
        OptimizeFor=0,
        Range=0,
        Item=0,
        IncludeDocProps=True,
        KeepIRM=True,
        CreateBookmarks=1,
        DocStructureTags=True,
        BitmapMissingFonts=True,
        UseISO19005_1=False,
    )
    doc.Close(SaveChanges=False)
finally:
    word.Quit()
print('exported:', PDF)
