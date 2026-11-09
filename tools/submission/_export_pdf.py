# -*- coding: utf-8 -*-
"""Export the final deck to PDF for submission."""
import os
import win32com.client as win32

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(BASE))
PPTX = os.path.join(ROOT, 'submission', 'StarGate_答辩PPT.pptx')
PDF = os.path.join(ROOT, 'submission', 'StarGate_答辩PPT.pdf')

ppt = win32.DispatchEx('PowerPoint.Application')
try:
    pres = ppt.Presentations.Open(PPTX, WithWindow=False)
    pres.SaveAs(PDF, 32)  # ppSaveAsPDF
    pres.Close()
finally:
    ppt.Quit()
print('exported', PDF)
