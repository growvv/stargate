# -*- coding: utf-8 -*-
"""Build the StarGate competition document (DOCX)."""
import os
from docx import Document
from docx.shared import Pt, Cm, RGBColor, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.section import WD_SECTION
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.enum.text import WD_BREAK

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(BASE))
A = os.path.join(BASE, 'assets')
OUT = os.path.join(ROOT, 'submission', 'StarGate_项目文档.docx')

NAVY = RGBColor(0x1F, 0x38, 0x64)
BLUE = RGBColor(0x2E, 0x75, 0xB6)
TEAL = RGBColor(0x2F, 0x9E, 0x8F)
RED = RGBColor(0xC0, 0x00, 0x00)
GRAY = RGBColor(0x59, 0x59, 0x59)
LGRAY = RGBColor(0x80, 0x80, 0x80)
BLACK = RGBColor(0x1A, 0x1A, 0x1A)

BODY_FONT = '宋体'
HEAD_FONT = '微软雅黑'


def set_cn(run, font=BODY_FONT):
    run.font.name = font
    rPr = run._element.get_or_add_rPr()
    rFonts = rPr.find(qn('w:rFonts'))
    if rFonts is None:
        rFonts = OxmlElement('w:rFonts')
        rPr.append(rFonts)
    rFonts.set(qn('w:eastAsia'), font)
    rFonts.set(qn('w:ascii'), font)
    rFonts.set(qn('w:hAnsi'), font)


def style_run(run, size=10.5, color=BLACK, bold=False, italic=False, font=BODY_FONT):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.color.rgb = color
    set_cn(run, font)


def body(text, indent=True, space_after=6, size=10.5, align=WD_ALIGN_PARAGRAPH.JUSTIFY):
    p = doc.add_paragraph()
    p.alignment = align
    p.paragraph_format.line_spacing = 1.5
    p.paragraph_format.space_after = Pt(space_after)
    if indent:
        p.paragraph_format.first_line_indent = Cm(0.74)
    run = p.add_run(text)
    style_run(run, size)
    return p


def rich_body(parts, indent=True, space_after=6):
    """parts = [(text, bold, color), ...]"""
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p.paragraph_format.line_spacing = 1.5
    p.paragraph_format.space_after = Pt(space_after)
    if indent:
        p.paragraph_format.first_line_indent = Cm(0.74)
    for text, bold, color in parts:
        run = p.add_run(text)
        style_run(run, 10.5, color, bold)
    return p


def h1(num, text=None, new_page=False):
    if text is None:
        label = num
    elif num.startswith('附录'):
        label = num + '  ' + text
    else:
        label = ('第%s章  ' % num) + text
    p = doc.add_paragraph()
    p.style = doc.styles['Heading 1']
    p.paragraph_format.space_before = Pt(16)
    p.paragraph_format.space_after = Pt(9)
    p.paragraph_format.keep_with_next = True
    if new_page:
        p.paragraph_format.page_break_before = True
    run = p.add_run(label)
    style_run(run, 16, NAVY, True, font=HEAD_FONT)
    pPr = p._p.get_or_add_pPr()
    pBdr = OxmlElement('w:pBdr')
    bottom = OxmlElement('w:bottom')
    bottom.set(qn('w:val'), 'single')
    bottom.set(qn('w:sz'), '14')
    bottom.set(qn('w:space'), '4')
    bottom.set(qn('w:color'), '2E75B6')
    pBdr.append(bottom)
    pPr.append(pBdr)
    return p


def h2(text):
    p = doc.add_paragraph()
    p.style = doc.styles['Heading 2']
    p.paragraph_format.space_before = Pt(12)
    p.paragraph_format.space_after = Pt(6)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    style_run(run, 13.5, BLUE, True, font=HEAD_FONT)
    return p


def h3(text):
    p = doc.add_paragraph()
    p.style = doc.styles['Heading 3']
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    style_run(run, 11.5, BLACK, True, font=HEAD_FONT)
    return p


def bullet(text):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(0.74)
    p.paragraph_format.first_line_indent = Cm(-0.37)
    p.paragraph_format.line_spacing = 1.4
    p.paragraph_format.space_after = Pt(2)
    run = p.add_run('· ')
    style_run(run, 10.5, BLUE, True)
    run = p.add_run(text)
    style_run(run, 10.5)
    return p


def caption(text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(8)
    run = p.add_run(text)
    style_run(run, 9, GRAY)


def figure(name, width_cm, cap, height_cm=None):
    path = os.path.join(A, name)
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(2)
    run = p.add_run()
    if height_cm:
        run.add_picture(path, height=Cm(height_cm))
    else:
        run.add_picture(path, width=Cm(width_cm))
    caption(cap)


def pic_pair(name1, cap1, name2, cap2, width_cm=7.0):
    table = doc.add_table(rows=1, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for idx, (name, cap) in enumerate([(name1, cap1), (name2, cap2)]):
        cell = table.cell(0, idx)
        cell.width = Cm(8.0)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = p.add_run()
        run.add_picture(os.path.join(A, name), width=Cm(width_cm))
        cp = cell.add_paragraph()
        cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        r = cp.add_run(cap)
        style_run(r, 9, GRAY)


def shade(cell, hex_color):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), hex_color)
    tcPr.append(shd)


def set_cell_margins(cell, top=40, bottom=40, left=80, right=80):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = OxmlElement('w:tcMar')
    for name, val in [('top', top), ('bottom', bottom), ('start', left), ('end', right)]:
        el = OxmlElement('w:' + name)
        el.set(qn('w:w'), str(val))
        el.set(qn('w:type'), 'dxa')
        tcMar.append(el)
    tcPr.append(tcMar)


def table(headers, rows, widths, cap):
    caption(cap)
    t = doc.add_table(rows=len(rows) + 1, cols=len(headers))
    t.style = 'Table Grid'
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    t.autofit = False
    for c, h in enumerate(headers):
        cell = t.cell(0, c)
        cell.width = Cm(widths[c])
        shade(cell, '1F3864')
        set_cell_margins(cell)
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = p.add_run(h)
        style_run(run, 9.5, RGBColor(0xFF, 0xFF, 0xFF), True, font=HEAD_FONT)
    for r, row in enumerate(rows, start=1):
        for c, val in enumerate(row):
            cell = t.cell(r, c)
            cell.width = Cm(widths[c])
            set_cell_margins(cell)
            if r % 2 == 0:
                shade(cell, 'F2F7FC')
            p = cell.paragraphs[0]
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT if c else WD_ALIGN_PARAGRAPH.CENTER
            p.paragraph_format.line_spacing = 1.15
            p.paragraph_format.space_after = Pt(1)
            run = p.add_run(val)
            style_run(run, 9, BLACK, c == 0)
    for idx, row in enumerate(t.rows):
        trPr = row._tr.get_or_add_trPr()
        cantSplit = OxmlElement('w:cantSplit')
        trPr.append(cantSplit)
        if idx == 0:
            trPr.append(OxmlElement('w:tblHeader'))
    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return t


def add_field(paragraph, instr):
    run = paragraph.add_run()
    fld_begin = OxmlElement('w:fldChar')
    fld_begin.set(qn('w:fldCharType'), 'begin')
    run._r.append(fld_begin)
    run2 = paragraph.add_run()
    instrText = OxmlElement('w:instrText')
    instrText.set(qn('xml:space'), 'preserve')
    instrText.text = instr
    run2._r.append(instrText)
    run3 = paragraph.add_run()
    fld_sep = OxmlElement('w:fldChar')
    fld_sep.set(qn('w:fldCharType'), 'separate')
    run3._r.append(fld_sep)
    run4 = paragraph.add_run('1')
    style_run(run4, 9, GRAY)
    run5 = paragraph.add_run()
    fld_end = OxmlElement('w:fldChar')
    fld_end.set(qn('w:fldCharType'), 'end')
    run5._r.append(fld_end)


def add_toc_field():
    p = doc.add_paragraph()
    run = p.add_run()
    fldChar = OxmlElement('w:fldChar')
    fldChar.set(qn('w:fldCharType'), 'begin')
    run._r.append(fldChar)
    instr = OxmlElement('w:instrText')
    instr.set(qn('xml:space'), 'preserve')
    instr.text = 'TOC \\o "1-2" \\h \\z \\u'
    run._r.append(instr)
    fldChar2 = OxmlElement('w:fldChar')
    fldChar2.set(qn('w:fldCharType'), 'separate')
    run._r.append(fldChar2)
    run2 = p.add_run('目录将在打开文档时自动更新。')
    style_run(run2, 10, GRAY)
    run3 = p.add_run()
    fldChar3 = OxmlElement('w:fldChar')
    fldChar3.set(qn('w:fldCharType'), 'end')
    run3._r.append(fldChar3)


def page_break():
    doc.add_page_break()


# ================================================================ setup
doc = Document()
sec = doc.sections[0]
sec.page_width = Cm(21.0)
sec.page_height = Cm(29.7)
sec.top_margin = Cm(2.2)
sec.bottom_margin = Cm(2.2)
sec.left_margin = Cm(2.4)
sec.right_margin = Cm(2.4)
sec.header_distance = Cm(1.2)
sec.footer_distance = Cm(1.2)

normal = doc.styles['Normal']
normal.font.name = BODY_FONT
normal.font.size = Pt(10.5)
normal.element.rPr.rFonts.set(qn('w:eastAsia'), BODY_FONT)

# settings: update fields on open
settings = doc.settings.element
update = OxmlElement('w:updateFields')
update.set(qn('w:val'), 'true')
settings.append(update)

sec.different_first_page_header_footer = True

# header / footer
hp = sec.header.paragraphs[0]
hp.alignment = WD_ALIGN_PARAGRAPH.CENTER
hr = hp.add_run('星门 StarGate · 开源鸿蒙移动应用创新成果申报')
style_run(hr, 8, LGRAY)
pPr = hp._p.get_or_add_pPr()
pBdr = OxmlElement('w:pBdr')
bottom = OxmlElement('w:bottom')
bottom.set(qn('w:val'), 'single')
bottom.set(qn('w:sz'), '4')
bottom.set(qn('w:space'), '1')
bottom.set(qn('w:color'), 'BFBFBF')
pBdr.append(bottom)
pPr.append(pBdr)

fp = sec.footer.paragraphs[0]
fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = fp.add_run('— ')
style_run(r, 9, GRAY)
add_field(fp, 'PAGE')
r = fp.add_run(' —')
style_run(r, 9, GRAY)

# ================================================================ cover
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(10)
run = p.add_run()
run.add_picture(os.path.join(A, 'logo.png'), width=Cm(2.6))

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(14)
run = p.add_run('开源鸿蒙移动应用创新成果申报')
style_run(run, 16, NAVY, True, font=HEAD_FONT)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(46)
run = p.add_run('星门 StarGate')
style_run(run, 34, NAVY, True, font=HEAD_FONT)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(10)
run = p.add_run('面向 HarmonyOS 的应用原子能力\n智能聚合与直达平台')
style_run(run, 18, BLUE, True, font=HEAD_FONT)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(18)
run = p.add_run('跨过 App 的门，一步抵达功能')
style_run(run, 12, GRAY, False, True, HEAD_FONT)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(40)
run = p.add_run('多应用覆盖   ·   多场景分类   ·   持续扩展')
style_run(run, 11, TEAL, True, font=HEAD_FONT)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(100)
run = p.add_run('项目负责人：刘发荣')
style_run(run, 12, NAVY, True, font=HEAD_FONT)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(6)
run = p.add_run('成果完成单位：软件学院 SMAT 项目组')
style_run(run, 12, NAVY, True, font=HEAD_FONT)

p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(6)
run = p.add_run('2026 年 11 月')
style_run(run, 12, NAVY, False, font=HEAD_FONT)

page_break()

# ================================================================ abstract
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(6)
p.paragraph_format.space_after = Pt(14)
run = p.add_run('摘  要')
style_run(run, 20, NAVY, True, font=HEAD_FONT)

abstract = (
    '移动应用已经覆盖生活与工作的几乎全部场景，但用户真正需要的往往不是某个 App，'
    '而是 App 里的某一个功能。功能被层层菜单包裹，用户需要先找 App、再找入口，路径长、'
    '记忆成本高；系统侧也只掌握“安装了哪些 App”，并不掌握“能直达哪些功能”。'
    '星门 StarGate 以 HarmonyOS NEXT 的桌面卡片为入口，提出“应用原子能力”的聚合'
    '与直达方法：从公开 Scheme、App Linking、系统 Shortcut 与静态分析线索中生产候选能力，'
    '经真机验证与证据分级后写入统一能力目录，再通过推荐排序、最近添加、A–Z# 分段搜索、'
    '分类浏览与能力探索五种方式分发，用户点击图标即可落到目标功能页。系统采用五层解耦'
    '架构，核心逻辑与 UI、系统 API 分离，配套自动化测试与真机验证流程；能力库'
    '覆盖主流应用与多个生活分类，并可随安装状态与能力发现持续扩展。'
    '星门把“找 App”变成“找功能”，为新形态操作系统上的能力分发提供了一种可落地、'
    '可解释、可扩展的范式。'
)
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
p.paragraph_format.line_spacing = 1.6
p.paragraph_format.first_line_indent = Cm(0.74)
run = p.add_run(abstract)
style_run(run, 10.5)

p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(16)
run = p.add_run('关键词：')
style_run(run, 10.5, NAVY, True)
run = p.add_run('HarmonyOS NEXT；原子能力；桌面卡片；能力分发；推荐排序；应用直达')
style_run(run, 10.5)

page_break()

# ================================================================ toc
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(4)
p.paragraph_format.space_after = Pt(14)
run = p.add_run('目  录')
style_run(run, 20, NAVY, True, font=HEAD_FONT)
add_toc_field()

page_break()

# ================================================================ chapter 1
h1('1', '背景与意义')

h2('1.1 移动应用生态的“功能孤岛”')
body('移动互联网经过十余年发展，已经形成了覆盖社交、支付、出行、购物、办公、生活服务、'
     '健康运动、娱乐等完整场景的应用生态。以本项目真实扫描的设备为例：一台普通手机上安装'
     '了多款与能力库相关的 App，能够提取出大量可被直接打开的功能入口。它们分布在多个'
     '分类中，其中大部分入口可以通过 Scheme 或 App Linking 直达目标页面，部分通用需求通过系统意图由用户'
     '选择目标应用。')
body('但对用户而言，App 只是容器，真正被需要的是容器里的功能。付款要打开支付 App，'
     '路线规划要打开地图 App，打开文档要打开办公 App，查快递要打开购物或物流 App。'
     '同一类需求往往散落在多个 App 中，用户必须先做一次“选 App”的决定，再做一次“找入口”'
     '的决定。App 越多，后一个决定越难。')
body('更隐蔽的问题在于，这些能力对系统是不可见的。系统知道用户安装了哪些 App，却不知道'
     '每个 App 能直接打开哪些页面；桌面只能摆放 App 图标，不能摆放“付款”“路线规划”'
     '“打开文档”这样的功能。能力被封装在各自的应用内，形成一个个“功能孤岛”。')

h2('1.2 用户侧：找功能比找 App 更难')
body('我们把一次典型使用拆成六个步骤：想完成一件事、解锁手机、在桌面找 App、打开 App、'
     '在 App 里找入口、到达功能页。六步之中，只有第一步和最后一步与“事情本身”有关，'
     '中间四步都是与工具搏斗。对于高频功能，用户尚能靠肌肉记忆缩短路径；对于低频但重要的'
     '功能——查航班、开发票、挂号、查快递——每次都要重新寻找。')
body('三类人群的痛点尤为明显。第一类是效率敏感型用户，他们每天多次使用支付、出行、'
     '文档、会议等功能，重复的寻找成本被高频放大。第二类是生活服务型用户，他们需要的功能'
     '分散在多个 App，且入口名称不统一，难以形成稳定记忆。第三类是长辈与数字弱势群体，'
     '他们不熟悉 App 品牌与层级结构，面对满屏图标常常无从下手。')
body('此外，App 版本更新会调整菜单结构，用户刚记住的入口可能在下一次更新后消失。'
     '入口的不稳定性进一步提高了学习成本，也让“把常用功能固定在桌面上”成为一种刚需。')

h2('1.3 平台侧：HarmonyOS 卡片带来的机会')
body('HarmonyOS NEXT 的 Stage 模型与 Form Kit 为上述问题提供了新的解法。桌面卡片可以'
     '常驻在桌面，不需要打开任何 App 就能展示信息与入口；卡片通过 postCardAction 可以直接'
     '触发路由或拉起目标页面；App Linking、Scheme 与 Shortcut 为跨应用跳转提供了公开、'
     '稳定的协议；bundleManager.canOpenLink 则让应用可以在本地探测某条路由是否可被系统'
     '打开。')
body('这意味着，“功能级入口”第一次具备了产品化的土壤：能力可以被发现、被验证、被组织、'
     '被推荐，并以卡片的形式直接呈现在用户最高频的桌面上。星门正是围绕这一机会设计的。')

h2('1.4 项目意义')
body('对用户，星门把“找 App”变成“找功能”。常用功能抬手上桌，低频功能可以按拼音首字母'
     '或分类快速定位，长辈也能按文字找到服务，不必理解 App 的内部结构。')
body('对生态，星门把 App 已经公开的入口转化为可发现、可复用、可组合的系统能力。它不要求'
     'App 改造，不要求接入新的 SDK，也不抓取用户数据；它做的是把公开协议整理成一张可维护'
     '的能力目录，让“藏在三级页面里的功能”重新被看见。')
body('对平台，星门验证了“卡片即分发”的可行性。桌面卡片不只是信息展示组件，也可以成为'
     '能力分发的载体：推荐负责“此刻最可能用”，最近添加负责“新装 App 的能力”，分类负责'
     '“按场景浏览”。这为 HarmonyOS 卡片生态提供了一种可复制的产品范式。')

h2('1.5 项目目标与边界')
body('项目目标可以概括为四句话：聚合多款 App 的原子能力；让每一次点击都落到目标'
     '功能页；让推荐有依据、可解释、可复现；让工程实现可测试、可维护、可扩展。')
body('项目边界同样明确。第一，只使用 App 公开声明的路由，不破解、不注入、不抓取私有接口。'
     '第二，只保留一条最可靠路由，不在运行时做多路由降级。第三，启动失败时明确报告'
     '“暂无可用直达入口”，不回退到 App 首页假装成功。第四，所有能力、用量、安装快照均保存在'
     '本机，不上云、不采集用户内容。')

# ================================================================ chapter 2
h1('2', '产品定义与使用场景')

h2('2.1 一句话定义')
body('星门 StarGate 是一个面向 HarmonyOS NEXT 的应用原子能力智能聚合与直达平台。它把'
     '多个 App 中可被直接打开的“功能”，聚合进一张桌面卡片和一组轻量页面，让用户'
     '不用先打开 App，就能一步抵达功能。')
body('“原子能力”是本项目的核心概念。它不是 App，也不是网页，而是一条“可被系统直接打开'
     '的目标页面 + 一条最可靠路由 + 一组证据与分类信息”。一条原子能力至少包含功能名、'
     '所属 App、目标包名、分类、路由、来源与置信度七个要素。')

h2('2.2 目标用户')
body('第一类是效率敏感型用户。他们每天高频使用支付、出行、文档、会议等能力，希望把常用'
     '功能固定在桌面，减少重复寻找。第二类是生活服务型用户。他们的需求跨越多个 App，'
     '希望按“我要做的事”而不是“我要打开的 App”来组织入口。第三类是长辈与数字弱势群体。'
     '他们更需要文字化、分类化、可搜索的入口，而不是记住图标位置。第四类是极客与尝鲜用户。'
     '他们愿意通过能力探索页查看每个入口的来源与证据，并直接验证。')

h2('2.3 四个入口')
body('星门提供四个互补的入口，覆盖“抬手就用、知道名字就搜、按场景逛、想看看还能做什么”'
     '四种心情。')
bullet('桌面卡片：常驻桌面，包含“推荐”“最近添加”两个功能框与分类 chips。'
       '点图标直接打开对应功能页；点“探索”进入能力探索页；点“更多”进入全部功能页。')
bullet('全部功能：按拼音首字母分为 A–Z# 段，左侧大字母标题、右侧常驻索引条，'
       '支持单字母拼音搜索与一键跳转；输入即筛，取消有明确语义。')
bullet('分类页：按购物、社交、支付、出行、生活、娱乐、健康运动、工具效率、其他等类目'
       '浏览该类目的全部能力，保留搜索框与展开文件夹式网格。')
bullet('能力探索：展示全部能力、可直接进入数量、待探测线索与探索路径；每条能力标注'
       '证据等级与来源，右侧提供“打开 ›”链接，可直接验证入口是否可用。')

h2('2.4 典型场景')
body('通勤场景：早上出门，用户在桌面卡片上直接点“路线规划”或“乘车码”，不必先打开地图'
     '或支付 App。出差前，点“按航班号查询”，系统意图会引导用户选择航班应用并直接进入查询页。')
body('办公场景：用户需要打开昨天的文档、加入会议或提交审批。卡片推荐会根据当日与当月'
     '使用频次，把 WPS、会议、审批等能力排在前面；如果用户记得功能名，直接在全部功能页'
     '输入首字母即可。')
body('生活场景：查快递、缴水电费、挂号、买药，这些低频但重要的功能散落在不同 App。'
     '分类页把它们按“生活”聚合，能力探索页则告诉用户每个入口的来源与可信度。')
body('长辈场景：长辈不需要理解 App 品牌与层级，只需在卡片上认字，或在全部功能页按拼音'
     '首字母找。文字标签、较大字号与清晰的分类，降低了数字门槛。')

h2('2.5 使用流程')
body('首次使用时，用户在桌面长按进入编辑状态，选择“卡片”，把 StarGate 的桌面卡片添加到'
     '桌面。卡片会自动读取本机能力库与用量快照，展示推荐与最近添加。用户点击任意图标，'
     '应用通过统一分发器构造一次明确的 Want，直接拉起目标功能页；如果目标入口不可用，'
     '卡片或页面会给出“暂无可用直达入口”的明确提示，而不是停留在首页。')
body('用户也可以从卡片进入全部功能、分类页、能力探索页与设置页。在设置页中，各分类'
     '支持长按拖动排序，顺序会持久化并实时同步到卡片；能力库支持外部 JSON 替换，开发期'
     '通过 hdc push 即可更新，不必重新打包。')

h2('2.6 设计原则')
bullet('单一最可靠路由：每条能力只保留一条最可靠路由，运行时不做多路由遍历与降级。')
bullet('失败即报告：入口不可用时明确返回失败，不回退 App 首页，不制造“成功”的假象。')
bullet('证据分级：每条能力标注来源与证据等级，只有通过真机验证的入口才进入生产目录。')
bullet('本地优先：能力库、用量、安装快照全部保存在本机，不依赖服务端，不上传用户数据。')
bullet('可解释、可复现：推荐公式公开、权重固定、同分按 id 排序；同样的输入必然得到同样的结果。')

# ================================================================ chapter 3
h1('3', '总体设计')

h2('3.1 设计目标')
body('星门的设计目标不是“做一个功能最多的启动器”，而是“做一条可信、可维护、可扩展的'
     '能力分发链路”。围绕这一目标，系统需要满足四个约束：入口与数据解耦，页面与系统 API'
     '解耦，核心逻辑可在 Node 环境直接测试，能力目录可在不重新打包的情况下更新。')

h2('3.2 五层架构')
body('系统采用入口层、编排层、能力层、数据层、系统层五层结构，层与层之间单向依赖。'
     '入口层只负责展示与交互，不直接读写数据；编排层负责把数据组装成页面或卡片需要的形状；'
     '能力层承载排序、探测、分组、搜索等纯逻辑；数据层负责能力、用量、安装与顺序的持久化；'
     '系统层封装 FormExtensionAbility、UIAbility、Preferences 与跨应用启动等平台能力。')
figure('arch.png', 16.0, '图 3-1  星门五层架构：入口 / 编排 / 能力 / 数据 / 系统')
body('这样的分层带来三个直接收益。第一，核心算法不依赖 UI 与 SDK，可以在 Node 环境中'
     '用真实 .ets 源码直接跑单测。第二，页面只消费编排层产出的数据，布局调整不会影响'
     '排序与探测逻辑。第三，系统 API 被收敛在系统层，未来适配不同设备形态时只需替换'
     '这一层。')
table(
    ['层级', '主要模块', '职责'],
    [
        ['入口层', '桌面卡片、全部功能、分类页、搜索、能力探索、设置', '展示与交互，不直接读写数据'],
        ['编排层', 'CardBinding、WidgetCardData、RefreshOrchestrator、PageRouter、LaunchDispatcher', '组装数据、编排刷新、分发启动'],
        ['能力层', 'RankingEngine、RecentAdditions、SearchFilter / PinyinUtil、LetterSections、CategoryOrder、CapabilityExplorer', '纯逻辑能力，不依赖 UI 与 SDK'],
        ['数据层', 'CapabilityRepository、EffectiveCatalog、InstallSnapshot、UsageStore、CategoryOrderStore、DiscoveryCandidateCatalog', '能力、用量、安装与顺序的持久化'],
        ['系统层', 'FormExtensionAbility、UIAbility、Preferences、bundleManager.canOpenLink、startAbility', '系统生命周期与跨应用启动'],
    ],
    [2.2, 7.6, 6.0], '表 3-1  五层架构职责'
)

h2('3.3 能力从生产到分发')
body('能力链路分为四段：生产、准入、分发、回流。生产段从能力库种子、应用模板、安装探测与'
     '发现候选目录中收集入口；准入段通过 EffectiveCatalog 做安装状态过滤与证据标注，只把'
     '真机可打开的 L0 入口写入生产目录；分发段由 RankingEngine、RecentAdditions、'
     'SearchFilter、LetterSections 与 CategoryOrder 共同决定“给谁看、排第几、怎么分组”；'
     '回流段把点击用量、安装变化与分类顺序写回本机存储，驱动下一次推荐。')
figure('flow.png', 16.0, '图 3-2  能力生产、分发与回流')
body('以一次点击为例：用户在卡片上点“路线规划”，LaunchDispatcher 根据该能力的单条路由'
     '构造 Want，调用系统 startAbility；成功后 UsageStore 记录一次使用，RankingEngine 在'
     '下一次刷新时提高该能力的分数；如果启动失败，CardFeedback 保留失败信息并在卡片上'
     '显示“暂无可用直达入口”。整个过程没有服务端参与，也不产生网络请求。')

h2('3.4 关键数据结构')
body('系统围绕五个核心结构组织数据。AtomicFunction 描述一条原子能力；Route 描述一条'
     '最可靠路由；CardBindingData 描述一张卡片要渲染的全部内容；UsageSnapshot 描述用量；'
     'InstallSnapshot 描述安装与首次见到时间。所有结构均为显式接口或类，满足 ArkTS 的'
     '静态类型约束。')
table(
    ['结构', '关键字段', '作用'],
    [
        ['AtomicFunction', 'id、appName、bundleName、label、category、hint、route、source、confidence', '一条可被分发的原子能力'],
        ['Route', 'kind、uri、abilityName、moduleName、parameters', '单条最可靠路由，支持 deeplink / applinking / shortcut-param / want / vertical'],
        ['CardBindingData', 'frames、categories、greeting、failure', '卡片渲染数据：推荐、最近添加、分类与失败提示'],
        ['UsageSnapshot', 'dayCount、monthCount、lastUsedAt、hourAffinity、recentSequence', '用量快照，驱动推荐排序'],
        ['InstallSnapshot', 'installedIds、streak、bundleFirstSeen、bundlesProbedAt、appVersionFingerprint', '安装状态、首次见到时间与去抖指纹'],
    ],
    [2.9, 8.6, 4.3], '表 3-2  关键数据结构'
)

h2('3.5 模块清单')
body('项目按职责划分为数据、推荐、表单、页面、启动五组模块。数据组负责能力库、目录过滤、'
     '安装探测、用量、分类顺序与发现候选；推荐组负责排序与最近添加；表单组负责卡片绑定、'
     '卡片渲染、刷新编排与主题；页面组负责全部功能、分类、探索与设置；启动组负责 Want 构造、'
     '垂直入口与失败归一化。模块之间通过显式接口通信，避免隐式全局状态。')

# ================================================================ chapter 4
h1('4', '路线探索与最终选择')

h2('4.1 四条路线')
body('在确定最终方案之前，项目组系统探索了四条把用户送到目标功能页的路线。它们不是四个'
     '互斥的“创意”，而是四种不同层面的工程路径：有的解决“入口在哪里”，有的解决'
     '“入口怎么被触发”，有的解决“入口怎么被发现”。')
bullet('A 应用内快捷方式：用户长按 App 图标，系统展示 Shortcut 菜单，选择后进入指定功能页。'
       '优点是系统原生、体验稳定；缺点是覆盖范围取决于 App 是否主动提供快捷方式，且用户'
       '必须先找到 App 图标。')
bullet('B 链接路由：通过 Scheme、App Linking、二维码或卡片链接直接唤起目标页面。优点是'
       '覆盖广、精度高、可跨应用组合；缺点是需要逐条验证路由是否可用，且裸 URI 可能被'
       '任意 App 认领。')
bullet('C 系统选择器：应用提出“我要查快递 / 我要导航”等能力请求，由系统根据 type 与'
       'sceneType 选择合适的 App。优点是尊重系统意图、无需知道目标包名；缺点是用户每次'
       '都要做一次选择，直达精度较低。')
bullet('D 静态分析 + 测试：从 HAP、资源与代码中提取页面与路由线索，再通过受控 UI Test 或'
       '人工复核确认。优点是能触达未公开的隐藏页面，覆盖最广；缺点是成本高、需要持续回归，'
       '不能把推测直接写入生产目录。')
figure('routes.png', 16.0, '图 4-1  四条路线及其证据分级')

h2('4.2 证据分级')
body('四条路线产出的线索质量并不相同。项目组引入四级证据体系：已验证直达、REA 线索、'
     'UI Test 候选、人工确认。只有“已验证直达”和“人工确认”的入口可以进入生产目录；'
     'REA 线索与 UI Test 候选留在发现候选目录，等待进一步验证。证据分级既是对用户的'
     '透明度承诺，也是对工程质量的控制手段。')
table(
    ['证据等级', '来源', '含义', '生产准入'],
    [
        ['已验证直达', '系统 Shortcut、Link 特性、公开 Scheme', '真机点击后可落到目标页面', '是'],
        ['人工确认', '人工复核并录入', '入口稳定、可复现', '是'],
        ['REA 线索', '静态分析提取的页面与路由', '有结构线索，尚未真机确认', '否，留在候选目录'],
        ['UI Test 候选', '受控注入 / 测试态观察', '测试环境可见，稳定性待确认', '否，留在候选目录'],
        ['待探测', '声明扫描到但无可用线索', '需要继续分析', '否'],
    ],
    [2.6, 5.0, 5.6, 2.6], '表 4-1  证据等级与准入规则'
)

h2('4.3 路线对比')
body('从覆盖范围、直达精度、用户心智、工程成本与可维护性五个维度对比，四条路线各有取舍。'
     'A 路线体验最好但覆盖最窄；B 路线覆盖与精度最均衡；C 路线尊重系统意图但牺牲了直达性；'
     'D 路线覆盖最广但成本最高，适合作为能力生产线而不是运行时方案。')
table(
    ['维度', 'A 应用内快捷方式', 'B 链接路由', 'C 系统选择器', 'D 静态分析 + 测试'],
    [
        ['覆盖范围', '少，需 App 主动提供', '广，公开 Scheme / App Linking', '中，受系统意图限制', '最广，可触达隐藏页'],
        ['直达精度', '高', '高', '低，由系统选 App', '高，但需逐条验证'],
        ['用户心智', '长按才发现', '链接 / 卡片自然', '每次都要选 App', '不可见，需产品化'],
        ['工程成本', '低', '中', '低', '高'],
        ['可维护性', '依赖 App 更新', '中', '高', '需持续回归'],
        ['项目中的用法', '补充入口', '主力路线', '系统意图兜底', '能力生产线'],
    ],
    [2.2, 3.3, 3.5, 3.3, 3.5], '表 4-2  四条路线对比'
)

h2('4.4 最终路线')
body('最终方案不是“只选一条”，而是“以 B 为主、A/C 补充、D 做生产线”的组合路线：')
bullet('B 链接路由作为主力：能力库中的多项直达能力，主要来自公开 Scheme 与 App Linking。'
       '它们覆盖广、精度高，且可以直接嵌入卡片的点击事件。')
bullet('A 应用内快捷方式作为补充：对于提供了 Shortcut 的 App，保留其系统入口，作为'
       '“长按 App 也能到达”的第二通道。')
bullet('C 系统选择器作为兜底：对于“按航班号查询”“查快递”等没有固定目标包名的能力，'
       '使用 vertical 入口，由系统按类型匹配应用。')
bullet('D 静态分析 + 测试作为生产线：REA 与 UI Test 负责发现隐藏入口，人工复核后写入'
       '能力库；未通过验证的线索只留在候选目录，不进入生产。')
body('生产准入遵循 L0 原则：只有真机上点击后有反应、且落到目标功能页的入口才写入'
     'capabilities.json。能力库以 App 直达为主，覆盖 Deep Link 与 App Linking 两类路由；'
     '通用需求通过系统意图入口完成；来源上，公开 Link 特性、公开 Scheme 与'
     '人工确认共同构成生产能力库。')

h2('4.5 为什么不做多路由降级')
body('预研阶段曾考虑“一条路由失败就尝试下一条”的多路由降级方案。它看起来能提高成功率，'
     '但会带来三个问题：第一，失败原因被掩盖，用户不知道自己最终被带到了哪里；第二，'
     '裸 URI 可能被任意 App 认领，降级会让“打开成功”变成不可验证的假象；第三，多路由'
     '遍历会显著增加启动时延与维护成本。')
body('因此产品层最终只保留一条最可靠路由，并在 Want 中显式指定 bundleName。失败时'
     '返回 NO_AVAILABLE_ENTRY，由界面给出明确提示。宁可诚实地失败，也不虚假地成功。')

# ================================================================ chapter 5
h1('5', '核心模块实现')

h2('5.1 能力库与统一目录')
body('CapabilityRepository 是能力库的唯一入口，支持三种加载方式：外部可替换配置文件、'
     'HAP 内 rawfile 种子、直接注入的内存条目。开发期通过 hdc push 替换外部 JSON 即可'
     '更新能力库，不重新打包 HAP；生产环境回退到 rawfile 种子。加载器内置 UTF-8 解码器，'
     '逐字节处理 1 至 4 字节序列，避免中文 App 名被错误解码。')
body('解析阶段执行严格校验：条目必须包含 id、appName、bundleName、route、category，'
     'route.kind 必须属于 deeplink、applinking、shortcut-param、want、vertical 之一，'
     'category 必须属于预定义的合法类目，confidence 必须在 0 到 1 之间。非法条目被丢弃，'
     '空文本或损坏文件返回空数组，保证空态不崩溃。')
body('EffectiveCatalog 负责把“能力库”变成“当前可用的目录”：它根据安装状态过滤掉未安装'
     'App 的能力，保留 L0 已验证入口，并把模板类条目排除在卡片之外。最终得到的目录'
     '只保留当前设备上已安装、且通过准入的能力，并按分类组织；具体规模随设备安装情况变化。')

h2('5.2 安装探测与最近添加')
body('“最近添加”的定义是：用户最近安装或新检测到的 App 中，能力库能够覆盖到的功能。'
     '它替换了早期“最近打开”的设计，因为最近打开只反映旧习惯，不能帮助用户发现新能力。')
body('实现上，InstalledProbe 使用 bundleManager.canOpenLink 对本机能力库中的路由进行'
     '探测，得到当前已安装的 bundle 集合；RecentAdditions.mergeSeen 负责维护“首次见到”'
     '时间表：首次运行时把已有 App 全部记为 0，表示基线；之后新出现的 bundle 记为当前'
     '时间；本次未检测到的 bundle 从表中移除，卸载后重装会重新记录。')
body('选择阶段由 RecentAdditions.select 完成：先按首次见到时间降序，再按能力库中的'
     '位置降序；同一个 App 只占一格，系统意图入口（vertical）不参与；如果没有任何新 App，'
     '则用能力库尾部的最新条目做默认填充。这样，新装 App 会自动排到前面并替换默认填充，'
     '用户不需要任何配置。')

h2('5.3 推荐排序')
body('推荐排序由 RankingEngine 实现，采用七因子加权公式：')
p = doc.add_paragraph()
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(4)
p.paragraph_format.space_after = Pt(6)
run = p.add_run('score = 0.30·当日使用 + 0.20·当月使用 + 0.18·时间衰减 + 0.12·时段偏好\n'
                '+ 0.08·场景亲和 + 0.07·最近序列 + 0.05·置信度')
style_run(run, 10, BLUE, True, font='Consolas')
body('当日使用与当月使用按候选集最大值归一化；时间衰减使用 τ=36 小时的指数衰减，'
     '让“昨天的使用”明显重于“上个月的使用”；时段偏好来自历史小时分布，冷启动时改用'
     '按当前小时给出的类目先验——上午偏出行、支付、工具效率，晚间偏购物、娱乐、生活；'
     '场景亲和首版保留接口、常量置 0；最近序列命中给 1；置信度来自能力库。')
body('排序后执行类目打散：同一 category 最多 2 条，避免整屏都是购物或社交；候选不足时'
     '返回实际条数，绝不补位；同分按 id 字典序排序，保证结果可复现。')
figure('ranking.png', 12.0, '图 5-1  推荐排序的七因子权重')

h2('5.4 桌面卡片')
body('桌面卡片由 FormExtensionAbility 驱动。onAddForm 与 onUpdateForm 是同步回调，'
     '无法 await，因此卡片侧使用 CapabilityRepository.fromContextSync 同步读取能力库，'
     '再由 RefreshOrchestrator.resolve 组装 CardBindingData。卡片包含两个功能框：'
     '“推荐”展示排序后的前 4 条能力，“最近添加”展示新装 App 的能力；下方是分类'
     'chips，点击可进入对应分类页。')
body('每个功能图标下方都有文字标签，最多两行、超出省略；图标与标签作为一个整体可点击。'
     '点图标时通过 postCardAction 触发 router，进入统一分发流程。卡片不展示“最近打开”'
     '与“收藏”，避免信息重复；失败时在卡片底部显示明确提示。')
figure('card_widget.png', 10.5, '图 5-2  桌面卡片：推荐、最近添加与分类')

h2('5.5 全部功能与搜索')
body('全部功能页复刻了 iOS“App 资源库”的信息结构：顶部是胶囊搜索框与“取消”，'
     '内容按拼音首字母分为 A–Z# 段，每段左侧是大写字母标题，行内是 46vp 圆角图标、'
     '功能名、App 名与细分隔线，右侧常驻 AlphabetIndexer 索引条。点击索引字母可直接'
     '滚动到对应分段。')
body('搜索采用“一次加载、纯内存过滤”的策略：进入页面时读取全部能力并缓存，输入时只对'
     '缓存执行 SearchFilter 与 PinyinUtil，不再重复探测或读取文件。单字母搜索即可命中'
     '拼音首字母匹配的功能，例如输入 a 会返回“按航班号查询”“按起降地查询”。取消按钮'
     '遵循 iOS 语义：有输入时先清空，无输入时返回上一页。')
pic_pair('shot_all.png', '图 5-3  全部功能：A–Z# 分段与右侧索引',
         'shot_search.png', '图 5-4  单字母拼音搜索', 6.6)

h2('5.6 分类页与配置')
body('分类页保留“展开文件夹”式网格：顶部是分类名与搜索框，内容区是一个玻璃质感的外层框，'
     '内部按每行 4 个排列功能图标。每个图标带功能名与 App 名，点击直接打开对应功能。'
     '页面在数据不足时从顶部开始排列，短内容不会被 Scroll 垂直居中。')
body('设置页负责个性化。分类以 List 呈现，开启 editMode 后支持长按拖动；拖动开始时'
     '生成自定义预览，放下时由 CategoryOrder.move 计算新顺序，写入 CategoryOrderStore，'
     '并实时同步到卡片。能力库路径在设置页底部展示，开发期可直接替换外部 JSON。')
pic_pair('shot_category.png', '图 5-5  分类页：按场景浏览该类目全部能力',
         'shot_config.png', '图 5-6  设置页：分类长按拖动排序', 6.6)

h2('5.7 能力探索')
body('能力探索页承担“透明度”职责。页面顶部展示声明扫描与运行时候选的统计概览；'
     '中部概括全部能力、可直接进入与待探测线索三类状态；'
     '下方是四条探索路径：公开入口、'
     'REA 静态分析、UI Test 探测、人工确认。')
body('能力条目按证据等级标注“已验证直达”“REA 线索”“UI Test 候选”“人工确认”，'
     '并显示来源与路由类型。每条能力右侧提供“打开 ›”链接，点击即走统一分发器，'
     '可直接验证入口是否可用；失败时页面顶部显示明确提示。')
figure('shot_explorer.png', 7.6, '图 5-7  能力探索：证据分级与一键验证')

h2('5.8 分发与启动')
body('LaunchDispatcher 是唯一的启动入口。它只读取 fn.route 这一条最可靠路由，按 kind'
     '构造 Want：deeplink 与 applinking 使用 uri 与 parameters；shortcut-param 使用'
     'abilityName、moduleName 与 parameters；want 使用 uri、action 与可选 ability；'
     '所有分支都显式带上 bundleName，避免裸 URI 被其他 App 认领。')
body('vertical 是唯一例外：它不构造 Want，而是把 verticalType 与参数交给 '
     'startAbilityByType，由系统按类型匹配目标应用。启动成功后记录一次用量；失败则返回'
     ' ok=false 与 reason=NO_AVAILABLE_ENTRY，由界面归一化为“暂无可用直达入口”。'
     '运行时不尝试第二条路由，也不回退 App 首页。')

h2('5.9 刷新编排')
body('RefreshOrchestrator 负责把能力库、模板、安装探测、用量、失败反馈与主题状态'
     '组装成一次刷新结果。它返回不可变快照，绝不修改上一轮状态；安装 diff 采用双次确认'
     '与版本指纹去抖，避免 App 安装过程中的瞬时变化导致卡片抖动；首次开启路由探测时'
     '建立“最近添加”基线，后续只把新出现的 bundle 记为新增。')

# ================================================================ chapter 6
h1('6', '工程质量与验证')

h2('6.1 纯逻辑内核与自动化测试')
body('项目把排序、探测、去重、分组、搜索、路由构造等核心逻辑放在不依赖 UI 与 SDK 的'
     '纯 TypeScript 模块中，通过自研 Node 测试环境直接加载真实 .ets 源码运行。测试加载器'
     '提供 @ohos/hypium 与最小化的 SDK shim，使同一份源码既能在 ArkTS 编译器中构建，'
     '也能在 Node 中执行。')
body('测试覆盖排序与推荐、安装探测、目录过滤、'
     'UTF-8 解码、搜索与分组、Want 构造、失败语义、卡片编排、页面静态约束等域。'
     '每次改动后先跑逻辑测试，再上真机验证；纯逻辑测试可在 30 秒内跑完。')
table(
    ['测试域', '代表用例', '结果'],
    [
        ['排序与推荐', '七因子、类目打散、冷启动先验、同分确定性', '通过'],
        ['安装探测', '首次基线、新 App 识别、卸载重装', '通过'],
        ['目录与过滤', 'UTF-8 解码、非法条目校验、安装状态过滤', '通过'],
        ['搜索与分组', '拼音首字母、单字母搜索、A–Z# 分组', '通过'],
        ['启动与失败', '四种 Want 构造、vertical 分支、失败即报告', '通过'],
        ['卡片编排', '推荐 / 最近添加 / 分类、失败反馈、版本指纹', '通过'],
        ['页面静态约束', '分段列表、索引、拖动排序、搜索栏内缩', '通过'],
    ],
    [3.0, 9.6, 3.2], '表 6-1  自动化测试矩阵'
)

h2('6.2 真机验证')
body('逻辑测试通过后，项目在 HarmonyOS NEXT 真机上完成端到端验证。构建使用 DevEco'
     ' Studio 自带的 hvigor 与 JBR 21，产出已签名 HAP；通过 hdc install -r 安装后，'
     '使用 uitest uiInput 驱动点击、长按、输入与拖动，并用 snapshot_display 截图留档。')
table(
    ['验证场景', '操作', '结果'],
    [
        ['全部功能', '查看 A–Z# 分段、点索引 C、输入 a、点取消', '通过'],
        ['能力探索', '查看证据标签、点击 6 条「打开 ›」、首条打开高德地图', '通过'],
        ['设置', '长按拖动“支付”到第 3 行、关闭重开确认持久化', '通过'],
        ['桌面卡片', '确认推荐 / 最近添加 / 分类、图标文字完整、无重叠', '通过'],
        ['构建安装', 'hvigor 签名构建、hdc install -r、启动卡片与页面', '通过'],
    ],
    [3.0, 9.6, 3.2], '表 6-2  真机验证记录'
)

h2('6.3 性能与稳定性')
body('性能方面，全部功能页只在进入时读取一次能力库，输入时只做内存过滤，避免每按一个键'
     '就跨 bundle 探测；卡片侧使用同步读取，避免异步回调丢失；安装探测结果按轮次缓存，'
     '同一轮刷新只探测一次。')
body('稳定性方面，能力库解析对非法条目做丢弃而不是抛异常；刷新编排使用不可变快照，'
     '失败反馈在下一轮刷新中保留；卡片与页面共用同一个分发器，避免出现“卡片能开、页面不能开”'
     '的不一致。')

h2('6.4 隐私与安全')
body('星门只读取 App 的公开路由声明，不抓取联系人、位置、相册、账号等用户数据；能力库、'
     '用量、安装快照与分类顺序全部保存在本机 Preferences 或应用沙箱文件中，不上传云端；'
     '每次启动都带明确 bundleName，不使用裸 URI，不静默落到首页；能力探索页对每条能力'
     '标注来源与证据等级，失败时给出明确提示。项目分发的是“公开入口”，不是“用户数据”。')

# ================================================================ chapter 7
h1('7', '创新点与比较优势')

h2('7.1 四个创新点')
body('第一，功能粒度的能力目录。传统启动器组织的是 App 图标，星门组织的是原子功能；'
     '每条能力包含目标页面、路由、分类、来源与置信度，可以直接被搜索、推荐与分发。')
body('第二，证据分级的生产准入。项目没有把扫描到的所有链接直接塞进产品，而是建立'
     '“已验证直达 / 人工确认 / REA 线索 / UI Test 候选”四级证据体系，只有前两级进入'
     '生产目录。这让“覆盖广”与“可信”同时成立。')
body('第三，主动分发而非被动陈列。卡片同时承载推荐、最近添加与分类：推荐负责“此刻最可能用”，'
     '最近添加负责“新装 App 的能力”，分类负责“按场景浏览”。三种逻辑互补，覆盖不同心情。')
body('第四，可解释、可复现的推荐。七因子公式、固定权重、36 小时衰减、类目打散与同分'
     '排序全部公开且确定；能力探索页展示证据来源；测试覆盖排序与探测的关键分支。'
     '推荐结果不是黑盒。')

h2('7.2 与同类方案的对比')
body('与传统启动器相比，星门的组织单位从 App 变成功能，支持直达目标页面、按七因子推荐、'
     '展示证据等级，并能感知新装 App；与系统全局搜索相比，星门不只搜索 App 与网页，'
     '而是搜索可直达的原子功能，并提供卡片常驻入口与可解释的证据链。')
table(
    ['能力', '传统启动器', '系统全局搜索', '星门 StarGate'],
    [
        ['组织单位', 'App 图标', 'App 与网页', '原子功能'],
        ['直达能力', '只能开首页', '部分 deep link', '单条最可靠路由'],
        ['推荐依据', '使用频率', '搜索历史', '七因子 + 时段 + 类目打散'],
        ['可解释性', '无', '无', '证据分级 + 来源'],
        ['最近添加', '无', '无', '安装探测自动上桌'],
        ['覆盖范围', '已安装 App', '可搜索内容', '多款 App · 多项能力'],
    ],
    [2.6, 3.6, 3.6, 6.0], '表 7-1  与同类方案的对比'
)

h2('7.3 社会与经济效益')
body('社会效益方面，星门降低了数字门槛。长辈不必理解 App 品牌与层级，按文字或拼音即可'
     '找到服务；低频重要功能不再因为“藏得深”而被遗忘；公开入口被重新组织，延长了 App'
     '功能的使用寿命。')
body('经济效益方面，星门为 App 提供了一条不改造、不接入 SDK 的“功能曝光”通道。'
     '对中小开发者，功能可以被更多用户看见；对平台，卡片成为新的分发位；对用户，'
     '操作路径缩短，时间成本下降。三方收益在同一个能力目录上达成一致。')

# ================================================================ chapter 8
h1('8', '总结与展望')

h2('8.1 总结')
body('星门 StarGate 完成了从“能力生产”到“能力分发”的完整闭环：以公开 Scheme、'
     'App Linking、Shortcut 与静态分析线索为来源，以证据分级为准入，以统一能力目录为'
     '单一事实源，以桌面卡片、全部功能、分类、搜索与能力探索为分发面，以统一分发器'
     '直达目标功能页。能力库覆盖主流应用与多个生活分类，并可随安装与发现持续扩展；自动化'
     '测试与真机验证全部通过；签名 HAP 可直接安装。')
body('项目最重要的不是“做了多少功能”，而是验证了一种方法：App 是容器，功能才是服务；'
     '把功能从容器里请出来，需要对入口的敬畏、对证据的坚持和对用户体验的克制。')

h2('8.2 展望')
body('下一阶段，能力库将继续扩充，覆盖更多 App 与系统意图；推荐将引入时间、地点、'
     '设备状态等场景信号，让“此刻最可能用”更准确；能力接入规范将逐步沉淀，向开发者'
     '开放，让更多公开入口进入目录。星门已经打开，功能直达的路径会越来越短。')

# ================================================================ appendix
h1('附录 A', '能力库构成', new_page=True)
table(
    ['维度', '构成', '说明'],
    [
        ['能力来源', '公开 Scheme / App Linking / Shortcut', '应用公开声明的入口'],
        ['扩展来源', '静态分析 / UI Test / 人工确认', '补充未公开但可验证的入口'],
        ['能力分类', '出行、购物、办公、生活服务等', '按用户场景组织，可继续扩充'],
        ['分发入口', '桌面卡片 / 全部功能 / 分类 / 能力探索', '同一份目录，多种到达方式'],
        ['准入状态', '已验证直达 / 待验证线索', '验证通过才进入正式分发'],
    ],
    [3.6, 8.4, 6.0], '表 A-1  能力库构成与准入方式'
)

h1('附录 B', '术语表')
table(
    ['术语', '含义'],
    [
        ['原子能力', '一条可被系统直接打开的目标页面及其最可靠路由、分类与证据信息'],
        ['L0', '真机点击后可落到目标功能页的已验证入口'],
        ['Want', 'HarmonyOS 的跨应用启动描述，包含 bundleName、uri、abilityName 等字段'],
        ['App Linking', '基于 HTTPS 域名校验的应用间跳转协议'],
        ['Deep Link', '基于自定义 Scheme 的应用内页面跳转'],
        ['vertical', '通过 startAbilityByType 交给系统按类型匹配目标应用的入口'],
        ['证据分级', '按来源与验证程度划分的四级可信度体系'],
        ['最近添加', '最近安装或新检测到的 App 中，能力库能够覆盖到的功能'],
    ],
    [4.0, 12.0], '表 B-1  术语表'
)

h1('参考文献')
refs = [
    '[1] 华为开发者联盟. HarmonyOS NEXT 应用开发文档[EB/OL]. https://developer.huawei.com/.',
    '[2] 华为开发者联盟. Form Kit 卡片开发指南[EB/OL]. https://developer.huawei.com/.',
    '[3] 华为开发者联盟. App Linking 开发指南[EB/OL]. https://developer.huawei.com/.',
    '[4] 华为开发者联盟. ArkTS 语言规范[EB/OL]. https://developer.huawei.com/.',
    '[5] 软件学院 SMAT 项目组. StarGate 能力库 capabilities.json（2026-11 版）[Z]. 2026.',
    '[6] 软件学院 SMAT 项目组. StarGate 测试报告与真机验证记录[R]. 2026.',
]
for ref in refs:
    p = doc.add_paragraph()
    p.paragraph_format.line_spacing = 1.4
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.left_indent = Cm(0.74)
    p.paragraph_format.first_line_indent = Cm(-0.74)
    run = p.add_run(ref)
    style_run(run, 9.5)

doc.save(OUT)
print('saved', OUT)
