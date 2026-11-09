# -*- coding: utf-8 -*-
"""Build the StarGate competition deck (compact 12-slide cut)."""
import os
from PIL import Image
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR, MSO_AUTO_SIZE
from pptx.enum.shapes import MSO_SHAPE
from pptx.oxml.ns import qn

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(BASE))
A = os.path.join(BASE, 'assets')
OUT = os.path.join(ROOT, 'submission', 'StarGate_答辩PPT.pptx')

NAVY = RGBColor(0x1F, 0x38, 0x64)
BLUE = RGBColor(0x2E, 0x75, 0xB6)
MBLUE = RGBColor(0x5B, 0x9B, 0xD5)
LBLUE = RGBColor(0xDE, 0xEB, 0xF7)
XLBLUE = RGBColor(0xF2, 0xF7, 0xFC)
TEAL = RGBColor(0x2F, 0x9E, 0x8F)
ORANGE = RGBColor(0xED, 0x7D, 0x31)
PURPLE = RGBColor(0x7F, 0x5F, 0xA8)
RED = RGBColor(0xC0, 0x00, 0x00)
GREEN = RGBColor(0x54, 0x82, 0x35)
YELLOW = RGBColor(0xFF, 0xD9, 0x66)
INK = RGBColor(0x26, 0x26, 0x26)
GRAY = RGBColor(0x59, 0x59, 0x59)
DGRAY = RGBColor(0x40, 0x40, 0x40)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
BORDER = RGBColor(0xD6, 0xE2, 0xF2)
FONT = '微软雅黑'

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)
BLANK = prs.slide_layouts[6]


# ---------------------------------------------------------------- helpers
def _style_run(run, size=14, color=INK, bold=False, italic=False, font=FONT):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.color.rgb = color
    run.font.name = font
    rPr = run._r.get_or_add_rPr()
    ea = rPr.find(qn('a:ea'))
    if ea is None:
        ea = rPr.makeelement(qn('a:ea'), {})
        rPr.append(ea)
    ea.set('typeface', font)


def P(*runs, size=14, color=INK, bold=False, align=None, ls=1.12, before=0, after=0):
    prepared = []
    inferred = align
    for r in runs:
        if isinstance(r, str):
            prepared.append((r, (size, color, bold)))
        else:
            prepared.append(r)
            if inferred is None and r[1].get('align') is not None:
                inferred = r[1]['align']
    return {'runs': prepared, 'align': inferred or PP_ALIGN.LEFT,
            'ls': ls, 'before': before, 'after': after}


def R(text, size=14, color=INK, bold=False, italic=False, align=None, font=FONT):
    return (text, {'size': size, 'color': color, 'bold': bold,
                   'italic': italic, 'align': align, 'font': font})


def text(slide, x, y, w, h, paras, anchor=MSO_ANCHOR.TOP, wrap=True,
         margins=(0.02, 0.02, 0.02, 0.02)):
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = wrap
    tf.auto_size = MSO_AUTO_SIZE.NONE
    tf.vertical_anchor = anchor
    tf.margin_left = Inches(margins[0])
    tf.margin_right = Inches(margins[1])
    tf.margin_top = Inches(margins[2])
    tf.margin_bottom = Inches(margins[3])
    if isinstance(paras, dict):
        paras = [paras]
    for i, para in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = para.get('align', PP_ALIGN.LEFT)
        p.line_spacing = para.get('ls', 1.12)
        p.space_before = Pt(para.get('before', 0))
        p.space_after = Pt(para.get('after', 0))
        for item in para['runs']:
            if isinstance(item, str):
                run = p.add_run()
                run.text = item
                _style_run(run, para.get('size', 14), para.get('color', INK),
                           para.get('bold', False))
            else:
                run = p.add_run()
                run.text = item[0]
                st = item[1]
                _style_run(run, st.get('size', 14), st.get('color', INK),
                           st.get('bold', False), st.get('italic', False),
                           st.get('font', FONT))
    return tb


def box(slide, x, y, w, h, fill=WHITE, line=None, lw=1.0,
        kind=MSO_SHAPE.ROUNDED_RECTANGLE, radius=0.08):
    s = slide.shapes.add_shape(kind, Inches(x), Inches(y), Inches(w), Inches(h))
    if fill is None:
        s.fill.background()
    else:
        s.fill.solid()
        s.fill.fore_color.rgb = fill
    if line is None:
        s.line.fill.background()
    else:
        s.line.color.rgb = line
        s.line.width = Pt(lw)
    s.shadow.inherit = False
    if kind == MSO_SHAPE.ROUNDED_RECTANGLE:
        try:
            s.adjustments[0] = radius
        except Exception:
            pass
    return s


def bar(slide, x, y, w, h, fill):
    return box(slide, x, y, w, h, fill=fill, kind=MSO_SHAPE.RECTANGLE)


def diamond(slide, x, y, w, h, fill):
    return box(slide, x, y, w, h, fill=fill, kind=MSO_SHAPE.DIAMOND)


def arrow(slide, x, y, w, h, fill=BLUE, kind=MSO_SHAPE.RIGHT_ARROW):
    return box(slide, x, y, w, h, fill=fill, kind=kind)


def pic(slide, name, x, y, w, h, path_override=None):
    path = path_override or os.path.join(A, name)
    iw, ih = Image.open(path).size
    scale = min(w / iw, h / ih)
    nw, nh = iw * scale, ih * scale
    nx = x + (w - nw) / 2.0
    ny = y + (h - nh) / 2.0
    return slide.shapes.add_picture(path, Inches(nx), Inches(ny), Inches(nw), Inches(nh))


def title(slide, t):
    diamond(slide, 0.52, 0.28, 0.46, 0.46, LBLUE)
    diamond(slide, 0.43, 0.36, 0.40, 0.40, NAVY)
    text(slide, 1.00, 0.17, 11.15, 0.66,
         [P(R(t, 27, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
    bar(slide, 0.43, 0.90, 12.46, 0.022, BLUE)
    bar(slide, 0.43, 0.88, 1.15, 0.055, NAVY)


def beihang(slide, size=0.68, x=12.30, y=0.14):
    pic(slide, 'beihang_logo.png', x, y, size, size)


def banner(slide, runs):
    bar(slide, 0.0, 6.93, 13.333, 0.57, RED)
    text(slide, 0.45, 6.95, 12.45, 0.53,
         [P(*runs, size=16, color=WHITE, bold=True, align=PP_ALIGN.CENTER)],
         anchor=MSO_ANCHOR.MIDDLE)


def bullet(paras, label, desc, color=BLUE, size=14.5, dsize=13, gap=8):
    paras.append(P(R('■  ', size - 1, color), R(label, size, NAVY, True),
                   R('  ' + desc, dsize, DGRAY), ls=1.16, before=gap))


def card(slide, x, y, w, h, head, desc, col, hsize=16, dsize=13.5,
         fill=WHITE, head_color=NAVY):
    box(slide, x, y, w, h, fill=fill, line=BORDER, lw=1.2)
    bar(slide, x, y, 0.10, h, col)
    text(slide, x + 0.26, y + 0.14, w - 0.42, 0.36,
         [P(R(head, hsize, head_color, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(slide, x + 0.26, y + 0.55, w - 0.44, h - 0.65,
         [P(R(desc, dsize, DGRAY), ls=1.22)], anchor=MSO_ANCHOR.TOP)


def step_down(slide, x, y, w, h, label, col, size=13, fill=XLBLUE):
    box(slide, x, y, w, h, fill=fill, line=BORDER, lw=1.0)
    text(slide, x + 0.12, y, w - 0.2, h,
         [P(R(label, size, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
    return y + h


def lane_label(slide, x, y, w, h, num, name, col):
    box(slide, x, y, w, h, fill=col)
    text(slide, x, y + 0.10, w, h - 0.20,
         [P(R(num, 20, WHITE, True, align=PP_ALIGN.CENTER), ls=1.0),
          P(R(name, 13, WHITE, True, align=PP_ALIGN.CENTER), ls=1.0)],
         anchor=MSO_ANCHOR.MIDDLE)


# ================================================================ 1 cover
s = prs.slides.add_slide(BLANK)
text(s, 0.55, 0.20, 10.2, 0.50,
     [P(R('开源鸿蒙移动应用创新成果申报', 23, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
bar(s, 0.57, 0.76, 7.2, 0.035, NAVY)
pic(s, 'beihang_logo.png', 11.72, 0.12, 1.05, 1.05)
pic(s, 'logo.png', 6.17, 1.00, 0.95, 0.95)
text(s, 1.0, 2.02, 11.33, 0.90,
     [P(R('星门 StarGate', 47, NAVY, True, align=PP_ALIGN.CENTER))],
     anchor=MSO_ANCHOR.MIDDLE)
text(s, 1.0, 2.92, 11.33, 0.55,
     [P(R('面向 HarmonyOS 的应用原子能力智能聚合与直达平台', 23, BLUE, True,
          align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
text(s, 1.0, 3.50, 11.33, 0.42,
     [P(R('跨过 App 的门，一步抵达功能', 18, GRAY, False, True,
          align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)

lines = [('项目负责人：', '刘发荣'), ('成果完成单位：', '软件学院 SMAT 项目组')]
for i, (k, v) in enumerate(lines):
    text(s, 1.0, 4.62 + i * 0.46, 11.33, 0.36,
         [P(R(k, 15.5, NAVY, True), R(v, 15.5, NAVY, False, align=PP_ALIGN.CENTER))],
         anchor=MSO_ANCHOR.MIDDLE)
text(s, 1.0, 5.86, 11.33, 0.36,
     [P(R('2026 年 11 月', 15.5, NAVY, False, align=PP_ALIGN.CENTER))],
     anchor=MSO_ANCHOR.MIDDLE)
bar(s, 0.55, 7.10, 12.23, 0.03, LBLUE)

# ================================================================ 2 background & significance
s = prs.slides.add_slide(BLANK)
title(s, '背景与意义 —— 功能被埋在 App 深处')
beihang(s)
pains = [
    ('入口碎片化', '同一种需求散落在多个 App：先选 App，再找功能；一次任务先做一次「选 App」。', BLUE),
    ('层级太深', '核心功能藏在二级、三级页面，路径长、记不住；入口名称不统一，换版本就失效。', ORANGE),
    ('能力不可见', '系统知道装了什么 App，却不知道能直达哪些功能；桌面只能放图标，不能放功能。', TEAL),
]
for i, (h, d, col) in enumerate(pains):
    card(s, 0.45, 1.14 + i * 1.55, 5.45, 1.42, h, d, col, 18, 14.5)
text(s, 6.35, 1.12, 6.5, 0.36,
     [P(R('用户的一次真实路径', 16, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
steps = ['想完成一件事', '解锁手机', '在桌面找 App', '打开 App', '在 App 里找入口', '到达功能页']
for i, st in enumerate(steps):
    y = 1.55 + i * 0.67
    hot = i == 4
    box(s, 6.40, y, 6.40, 0.54,
        fill=RGBColor(0xF8, 0xE5, 0xE5) if hot else XLBLUE,
        line=RED if hot else BORDER, lw=1.2)
    text(s, 6.55, y, 0.45, 0.54,
         [P(R(str(i + 1), 15, RED if hot else BLUE, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, 7.02, y, 5.55, 0.54,
         [P(R(st, 14.5, RED if hot else NAVY, hot))], anchor=MSO_ANCHOR.MIDDLE)
    if i < 5:
        arrow(s, 9.45, y + 0.56, 0.26, 0.08, fill=MBLUE, kind=MSO_SHAPE.DOWN_ARROW)
text(s, 6.40, 5.62, 6.45, 0.42,
     [P(R('六步里，四步都在「找入口」。', 14.5, RED, True))], anchor=MSO_ANCHOR.MIDDLE)
box(s, 0.45, 6.16, 12.40, 0.66, fill=LBLUE)
text(s, 0.62, 6.16, 12.05, 0.66,
     [P(R('App 是容器，功能才是服务：', 15.5, NAVY, True),
        R('对用户少点几步，对生态让入口被看见，对平台让卡片成为新入口。', 15, DGRAY),
        ls=1.18)], anchor=MSO_ANCHOR.MIDDLE)
banner(s, [R('从「找 App」到「找功能」，', 16, WHITE, True),
           R('把入口放回桌面', 16.5, YELLOW, True), R('。', 16, WHITE, True)])

# ================================================================ 3 product + four entrances
s = prs.slides.add_slide(BLANK)
title(s, '产品 —— 一张桌面卡片，四个入口')
beihang(s)
text(s, 0.45, 1.10, 12.40, 0.48,
     [P(R('把散落在 App 里的功能，收进桌面上的「功能桌面」；不用先打开 App，就能一步抵达。',
          16.5, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
cards4 = [
    ('桌面卡片', '抬手就用', '推荐 / 最近添加 / 分类', 'card_widget.png', BLUE, '高频、固定场景'),
    ('搜索', '知道名字就搜', 'A–Z# 分段 + 拼音搜索', 'shot_all_card.png', TEAL, '记得功能名'),
    ('分类页', '按场景逛', '分类浏览，一屏一组', 'shot_category_card.png', ORANGE, '按场景浏览'),
    ('设置', '按习惯调整', '分类排序 + 卡片偏好', 'shot_config_card.png', PURPLE, '个性化'),
]
for i, (name, tag, desc, img, col, fit) in enumerate(cards4):
    x = 0.45 + i * 3.16
    box(s, x, 1.68, 3.00, 4.96, fill=WHITE, line=BORDER, lw=1.2)
    bar(s, x, 1.68, 3.00, 0.52, col)
    text(s, x, 1.68, 3.00, 0.52,
         [P(R(name, 17.5, WHITE, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
    pic(s, img, x + 0.14, 2.30, 2.72, 2.24)
    text(s, x + 0.17, 4.62, 2.66, 0.34,
         [P(R(tag, 14.5, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
    box(s, x + 0.17, 5.02, 1.18, 0.30, fill=col)
    text(s, x + 0.17, 5.02, 1.18, 0.30,
         [P(R(fit, 10.5, WHITE, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.17, 5.40, 2.66, 0.62,
         [P(R(desc, 12.5, DGRAY), ls=1.18)], anchor=MSO_ANCHOR.TOP)
    ex = ['例：付款码 · 扫一扫 · 查快递', '例：输入「支付」直接定位',
          '例：出行 / 购物 / 生活', '例：拖动分类 / 调整卡片'][i]
    text(s, x + 0.17, 5.98, 2.66, 0.40,
         [P(R(ex, 11.5, GRAY, False, True))], anchor=MSO_ANCHOR.MIDDLE)
banner(s, [R('同一份能力库，', 16, WHITE, True), R('四个入口', 16.5, YELLOW, True),
           R('。', 16, WHITE, True)])

# ================================================================ 4 widget
s = prs.slides.add_slide(BLANK)
title(s, '桌面卡片 —— 推荐 / 最近添加 / 分类 / 搜索')
beihang(s)
pic(s, 'card_widget.png', 0.45, 1.14, 5.35, 5.55)
blocks = [
    ('推荐', '按使用强度、时间衰减、时段偏好综合排序；同类目打散，避免单一类目刷屏。', BLUE),
    ('最近添加', '新装或新检测到的 App 自动上桌；每个 App 只占一格；首次基线不冒充新能力。', TEAL),
    ('分类', '按场景组织能力；长按拖动调整顺序，卡片与页面实时同步。', ORANGE),
    ('搜索', '与推荐、最近添加、分类并列；按 A–Z 浏览，也可直接输入中文或拼音定位。', PURPLE),
]
for i, (h, d, col) in enumerate(blocks):
    y = 1.16 + i * 1.27
    card(s, 6.10, y, 6.65, 1.16, h, d, col, 16, 12.2,
         fill=RGBColor(0xF2, 0xF7, 0xFC) if h == '搜索' else WHITE)
arrow(s, 5.82, 5.40, 0.26, 0.16, fill=PURPLE)
text(s, 6.10, 6.32, 6.65, 0.36,
     [P(R('点任意图标直达功能页；入口不可用会明确提示，不静默回首页。', 13, RED, True))],
     anchor=MSO_ANCHOR.MIDDLE)
banner(s, [R('卡片不是展示，', 16, WHITE, True), R('是入口', 16.5, YELLOW, True),
           R('。', 16, WHITE, True)])

# ================================================================ 5 all functions
s = prs.slides.add_slide(BLANK)
title(s, '搜索 —— A–Z 分段与拼音定位')
beihang(s)
pic(s, 'shot_all.png', 0.40, 1.12, 3.55, 5.58)
pic(s, 'shot_search.png', 4.15, 1.15, 4.35, 2.65)
box(s, 8.65, 1.15, 4.20, 2.65, fill=XLBLUE, line=BORDER, lw=1.0)
text(s, 8.82, 1.28, 3.88, 0.38,
     [P(R('输入即筛 · 字母即索引', 15, BLUE, True))], anchor=MSO_ANCHOR.MIDDLE)
text(s, 8.82, 1.76, 3.88, 1.90,
     [P(R('目录一次读入，输入只做内存过滤。', 13, DGRAY), ls=1.3, before=4),
      P(R('有字先清空，无字再返回。', 13, DGRAY), ls=1.3, before=4),
      P(R('拼音首字母、中文、单字母都能命中。', 13, DGRAY), ls=1.3, before=4),
      P(R('示例：输入 a → 航班查询相关功能。', 12.5, BLUE, True), ls=1.3, before=8)],
     anchor=MSO_ANCHOR.TOP)
feats = [
    ('A–Z# 分段', '按拼音首字母自动分组，长列表也能扫读'),
    ('右侧索引', '点字母直接跳到对应段，不来回滚动'),
    ('中文与拼音', '全名、首字母、单字母都能命中'),
    ('即时过滤', '目录一次读入，输入只做内存过滤'),
    ('结果分组', '按类型与字母归并，结果不混在一起'),
    ('取消语义', '有字先清空，无字再返回'),
]
for i, (h, d) in enumerate(feats):
    x = 4.15 + (i % 3) * 2.95
    y = 4.05 + (i // 3) * 1.18
    box(s, x, y, 2.75, 1.02, fill=WHITE, line=BORDER, lw=1.0)
    bar(s, x, y, 0.08, 1.02, BLUE if i % 2 == 0 else TEAL)
    text(s, x + 0.20, y + 0.10, 2.45, 0.30,
         [P(R(h, 13.5, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.20, y + 0.42, 2.45, 0.56,
         [P(R(d, 12, DGRAY), ls=1.12)], anchor=MSO_ANCHOR.TOP)
banner(s, [R('把能力装进一个', 16, WHITE, True), R('可搜索的字母表', 16.5, YELLOW, True),
           R('。', 16, WHITE, True)])

# ================================================================ 7 architecture / data flow
s = prs.slides.add_slide(BLANK)
title(s, '总体架构 —— 从能力来源到用户直达的数据流')
beihang(s)

# lane 1 sources
lane_label(s, 0.40, 1.10, 0.95, 1.34, '①', '来源', BLUE)
sources = [
    ('App 公开声明', 'Scheme / App Linking / Shortcut\n系统可校验的公开入口'),
    ('系统意图', 'startAbilityByType\n按能力类型匹配应用'),
    ('人工整理与复核', '开发者提交 / 真机确认\n补充可验证的公开入口'),
]
for i, (h, d) in enumerate(sources):
    x = 1.50 + i * 3.82
    box(s, x, 1.10, 3.62, 1.34, fill=WHITE, line=BORDER, lw=1.1)
    bar(s, x, 1.10, 0.09, 1.34, BLUE)
    text(s, x + 0.22, 1.18, 3.25, 0.34,
         [P(R(h, 14.5, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.22, 1.55, 3.28, 0.78,
         [P(R(d, 12.2, DGRAY), ls=1.16)], anchor=MSO_ANCHOR.TOP)
arrow(s, 6.55, 2.47, 0.30, 0.22, fill=MBLUE, kind=MSO_SHAPE.DOWN_ARROW)

# lane 2 production & admission
lane_label(s, 0.40, 2.73, 0.95, 1.45, '②', '生产准入', TEAL)
pipe = [
    ('声明扫描', '读取公开声明\n与系统意图'),
    ('候选池', '统一格式\n去重、标注来源'),
    ('可用性验证', '真机可打开\n才写入目录'),
    ('生产目录', '一条能力只保留\n一条最可靠路由'),
]
for i, (h, d) in enumerate(pipe):
    x = 1.50 + i * 2.84
    box(s, x, 2.73, 2.62, 1.45, fill=TEAL if h == '生产目录' else WHITE,
        line=TEAL, lw=1.2)
    text(s, x + 0.16, 2.82, 2.30, 0.34,
         [P(R(h, 14, WHITE if h == '生产目录' else NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.16, 3.20, 2.32, 0.82,
         [P(R(d, 12, WHITE if h == '生产目录' else DGRAY), ls=1.16)],
         anchor=MSO_ANCHOR.TOP)
    if i < 3:
        arrow(s, x + 2.64, 3.35, 0.18, 0.20, fill=MBLUE)

text(s, 1.55, 4.18, 9.0, 0.30,
     [P(R('统一能力目录：安装态过滤 · 分类 · 来源与验证状态，是呈现的唯一事实源', 12.5, TEAL, True))],
     anchor=MSO_ANCHOR.MIDDLE)
arrow(s, 11.33, 4.22, 0.26, 0.20, fill=MBLUE, kind=MSO_SHAPE.DOWN_ARROW)

# lane 3 presentation & feedback
lane_label(s, 0.40, 4.55, 0.95, 2.10, '③', '呈现反馈', ORANGE)
engines = [
    ('推荐排序', '加权公式 + 类目打散'),
    ('搜索与分组', '中文 / 拼音 / 字母'),
    ('最近添加', '安装探测 + 首次基线'),
    ('分类顺序', '用户拖动 + 持久化'),
]
for i, (h, d) in enumerate(engines):
    x = 1.50 + i * 2.84
    box(s, x, 4.55, 2.62, 0.78, fill=XLBLUE, line=BORDER, lw=1.0)
    text(s, x + 0.14, 4.57, 2.34, 0.34,
         [P(R(h, 13.5, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.14, 4.92, 2.34, 0.32,
         [P(R(d, 10.5, GRAY))], anchor=MSO_ANCHOR.MIDDLE)
    arrow(s, x + 1.18, 5.34, 0.26, 0.12, fill=MBLUE, kind=MSO_SHAPE.DOWN_ARROW)

entrances = ['桌面卡片', '搜索', '分类页']
for i, h in enumerate(entrances):
    x = 1.50 + i * 3.72
    box(s, x, 5.52, 3.55, 0.62, fill=ORANGE if i == 0 else WHITE, line=ORANGE, lw=1.2)
    text(s, x, 5.52, 3.55, 0.62,
         [P(R(h, 14.5, WHITE if i == 0 else NAVY, True, align=PP_ALIGN.CENTER))],
         anchor=MSO_ANCHOR.MIDDLE)
box(s, 1.50, 6.28, 11.06, 0.42, fill=RGBColor(0xFD, 0xF0, 0xE6))
text(s, 1.62, 6.28, 10.82, 0.42,
     [P(R('反馈回流：', 11.5, ORANGE, True),
        R('点击结果 / 使用频次 / 失败原因 → 驱动下一次排序与最近添加', 11.5, DGRAY))],
     anchor=MSO_ANCHOR.MIDDLE)
banner(s, [R('来源可查、准入有据、呈现清晰、', 15.5, WHITE, True),
           R('使用有回流', 16.5, YELLOW, True), R('。', 15.5, WHITE, True)])

# ================================================================ 8 routes explained
s = prs.slides.add_slide(BLANK)
title(s, '路线探索 —— 四种可能的直达方式')
beihang(s)
routes = [
    ('A 应用内快捷方式', '应用声明 shortcuts；系统长按菜单展示；点 shortcut 拉起目标页面。',
     '长按 App 图标，看到快捷方式，点一下进入', '入口自然、体验好；覆盖依赖 App 主动声明', BLUE, 'Shortcut'),
    ('B 链接路由', '用 App Linking / Deep Link 构造 Want；canOpenLink 先验证；startAbility 拉起目标 Ability。',
     '卡片、搜索结果直接打开功能页', '覆盖广、精度高；需要公开路由声明', TEAL, 'Want + startAbility'),
    ('C 系统选择器', 'startAbilityByType 发起能力请求；系统按类型匹配应用；由系统界面完成选择。',
     '系统弹出可选 App，选完继续', '无固定包名时兜底；多选一步，直达性弱', ORANGE, 'startAbilityByType'),
    ('D UI 步骤自动化', '预先录制或定制点击步骤，从桌面开始逐页点按，自动走到目标功能。',
     '页面自动跳转，用户只需等待', '直观、不依赖公开路由；步骤长、速度慢、怕改版', PURPLE, 'UI 自动化脚本'),
]
for i, (name, how, see, fit, col, api) in enumerate(routes):
    x = 0.42 + i * 3.15
    box(s, x, 1.10, 3.02, 5.58, fill=WHITE, line=BORDER, lw=1.2)
    bar(s, x, 1.10, 3.02, 0.56, col)
    text(s, x, 1.10, 3.02, 0.56,
         [P(R(name, 15.5, WHITE, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
    box(s, x + 0.16, 1.80, 1.70, 0.30, fill=LBLUE)
    text(s, x + 0.16, 1.80, 1.70, 0.30,
         [P(R(api, 10.5, NAVY, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.16, 2.20, 2.72, 0.28,
         [P(R('HarmonyOS 怎么做', 12.5, col, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.16, 2.50, 2.72, 1.35,
         [P(R(how, 13.5, DGRAY), ls=1.22)], anchor=MSO_ANCHOR.TOP)
    bar(s, x + 0.16, 3.95, 2.70, 0.015, BORDER)
    text(s, x + 0.16, 4.04, 2.72, 0.28,
         [P(R('用户看到什么', 12.5, col, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.16, 4.34, 2.80, 0.78,
         [P(R(see, 13, DGRAY), ls=1.2)], anchor=MSO_ANCHOR.TOP)
    bar(s, x + 0.16, 5.18, 2.70, 0.015, BORDER)
    text(s, x + 0.16, 5.27, 2.72, 0.28,
         [P(R('适合 / 局限', 12.5, col, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.16, 5.57, 2.80, 0.92,
         [P(R(fit, 13, DGRAY), ls=1.2)], anchor=MSO_ANCHOR.TOP)
banner(s, [R('最终选择：', 15.5, WHITE, True), R('B 为主，A/C 补场景，不采用 D', 16.5, YELLOW, True),
           R('。', 15.5, WHITE, True)])

# ================================================================ 9 final route
s = prs.slides.add_slide(BLANK)
title(s, '最终路线 —— 用 HarmonyOS 公开接口完成直达')
beihang(s)
text(s, 0.45, 1.04, 12.35, 0.38,
     [P(R('不注入、不模拟点击：App 声明入口，系统解析 Want，星门只把一次正确的请求交给系统。',
          14.5, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)

cols = [
    ('App 声明什么', BLUE, 'manifest', [
        ('module.json5 → abilities[].skills[]', '声明 actions 与 uris'),
        ('uris：scheme / host / path', '可响应哪一类链接'),
        ('shortcuts / App Linking', '快捷方式与 HTTPS 域名'),
        ('App 告诉系统', '我能接住哪些入口'),
    ]),
    ('系统提供什么', TEAL, 'HarmonyOS API', [
        ('Want', '跨应用启动的标准描述'),
        ('bundleManager.canOpenLink(uri)', '判断链接能否被系统打开'),
        ('UIAbilityContext.startAbility(want)', '按 bundleName / URI 找到目标 Ability'),
        ('startAbilityByType(type, param)', '按能力类型交给系统匹配'),
    ]),
    ('星门调用什么', ORANGE, 'one route · one Want', [
        ('能力库存一条最可靠路由', 'bundleName + uri'),
        ('点击时构造一个显式 Want', '不拼第二条路由'),
        ('context.startAbility(want)', '拉起目标功能页'),
        ('失败即返回 NO_AVAILABLE_ENTRY', '明确提示，不回退首页'),
    ]),
]
for i, (head, col, tag, rows) in enumerate(cols):
    x = 0.45 + i * 4.17
    box(s, x, 1.52, 3.95, 3.48, fill=WHITE, line=BORDER, lw=1.2)
    bar(s, x, 1.52, 3.95, 0.50, col)
    text(s, x, 1.52, 3.95, 0.50,
         [P(R(head, 16.5, WHITE, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
    box(s, x + 0.18, 2.14, 1.72, 0.30, fill=LBLUE)
    text(s, x + 0.18, 2.14, 1.72, 0.30,
         [P(R(tag, 10, NAVY, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
    paras = []
    for j, (k, d) in enumerate(rows):
        paras.append(P(R(k, 12.8, col if j < 2 else NAVY, True), ls=1.12,
                       before=10 if j else 14))
        paras.append(P(R(d, 12, DGRAY), ls=1.10, before=1))
    text(s, x + 0.20, 2.55, 3.55, 2.30, paras, anchor=MSO_ANCHOR.TOP)

box(s, 0.45, 5.15, 12.28, 1.57, fill=NAVY)
text(s, 0.64, 5.15, 11.95, 1.57, [
    P(R('示例  ', 11.5, YELLOW, True), R('高德地图 · 路线规划', 14.5, WHITE, True)),
    P(R('能力库：', 11.5, YELLOW, True),
      R('{ bundleName: "com.amap.hmapp", uri: "systemnav://routeplan" }',
        11.3, WHITE, font='Consolas'), before=5),
    P(R('点击：', 11.5, YELLOW, True),
      R('const want = { bundleName: "com.amap.hmapp", uri: "systemnav://routeplan" };  '
        'await context.startAbility(want);', 10.4, WHITE, font='Consolas'), before=3),
    P(R('系统把 URI 交给高德声明能响应的 Ability，直接打开路线规划页。', 12.2, LBLUE),
      before=4),
], anchor=MSO_ANCHOR.MIDDLE)
banner(s, [R('一次点击，', 15.5, WHITE, True), R('一个显式 Want', 16.5, YELLOW, True),
           R('，交给系统完成直达。', 15.5, WHITE, True)])

# ================================================================ 10 recommendation
s = prs.slides.add_slide(BLANK)
title(s, '推荐与最近添加 —— 让卡片先给出下一步')
beihang(s)
# left: ranking
text(s, 0.45, 1.12, 6.15, 0.40,
     [P(R('推荐：把此刻最可能用的放前面', 18, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
box(s, 0.55, 1.62, 6.05, 1.48, fill=NAVY)
text(s, 0.72, 1.66, 5.72, 1.40, [
    P(R('排序公式', 10.5, YELLOW, True)),
    P(R('score = 0.30·当日使用 + 0.20·当月使用', 12.4, WHITE, font='Consolas'), before=5),
    P(R('      + 0.18·时间衰减 + 0.12·时段偏好', 12.4, WHITE, font='Consolas'), before=1),
    P(R('      + 0.08·场景亲和 + 0.07·最近序列', 12.4, WHITE, font='Consolas'), before=1),
    P(R('      + 0.05·置信度', 12.4, WHITE, font='Consolas'), before=1),
], anchor=MSO_ANCHOR.MIDDLE)
paras = []
bullet(paras, '归一化', '当日 / 当月按候选集最大值归一化', NAVY, 12.8, 11.8, 8)
bullet(paras, '时间衰减', 'τ = 36 小时；昨天明显重于上个月', TEAL, 12.8, 11.8, 8)
bullet(paras, '时段偏好', '历史小时分布；冷启动用类目先验', ORANGE, 12.8, 11.8, 8)
bullet(paras, '排序约束', '同类目最多 2 条；同分按 id；不补位', PURPLE, 12.8, 11.8, 8)
text(s, 0.55, 3.34, 6.05, 2.30, paras)
# right: recent additions
text(s, 6.85, 1.12, 5.90, 0.40,
     [P(R('最近添加：新装 App 的能力自动上桌', 18, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
recent_steps = ['安装 / 更新 App', '探测公开路由', '记录首次出现', '每 App 取一格', '卡片展示']
for i, st in enumerate(recent_steps):
    y = 1.62 + i * 0.60
    box(s, 6.85, y, 5.90, 0.48, fill=XLBLUE, line=BORDER, lw=1.0)
    text(s, 7.02, y, 5.55, 0.48,
         [P(R(st, 13.5, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
    if i < 4:
        arrow(s, 9.55, y + 0.50, 0.24, 0.08, fill=MBLUE, kind=MSO_SHAPE.DOWN_ARROW)
paras = []
bullet(paras, '首次基线', '已有 App 记 0，不冒充新能力', NAVY, 13, 12, 8)
bullet(paras, '默认填充', '没有新 App 时用目录尾部补足', TEAL, 13, 12, 8)
bullet(paras, '卸载重装', '重新记录时间，符合直觉', ORANGE, 13, 12, 8)
text(s, 6.85, 4.85, 5.90, 1.25, paras)
box(s, 0.55, 6.28, 12.20, 0.42, fill=LBLUE)
text(s, 0.70, 6.28, 11.90, 0.42,
     [P(R('推荐负责「此刻最可能用」，最近添加负责「新装 App 的能力」，两者互补。',
          13.5, NAVY, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
banner(s, [R('推荐不是猜你喜欢，是', 15.5, WHITE, True),
           R('把下一步变短', 16.5, YELLOW, True), R('。', 15.5, WHITE, True)])

# ================================================================ 11 scenarios & ecosystem
s = prs.slides.add_slide(BLANK)
title(s, '应用场景与生态价值 —— 从效率工具到数字包容')
beihang(s)
scenes = [
    ('通勤路上', '乘车码、路线规划、航班查询，抬手上桌。', BLUE, '高德地图 · 路线规划\n12306 · 打开铁路'),
    ('办公协作', '文档、会议、审批，跳过 App 首页', TEAL, 'WPS · 打开文档\n会议 · 一键入会'),
    ('生活服务', '快递、缴费、挂号，按场景分类直达。', ORANGE, '快递 · 查快递\n支付 · 付款码'),
    ('长辈模式', '不用记图标，按功能名或拼音找', PURPLE, '按拼音首字母找\n按功能名找'),
]
for i, (h, d, col, ex) in enumerate(scenes):
    x = 0.45 + i * 3.13
    box(s, x, 1.12, 2.95, 2.62, fill=WHITE, line=BORDER, lw=1.2)
    bar(s, x, 1.12, 2.95, 0.10, col)
    box(s, x + 1.08, 1.38, 0.72, 0.72, fill=col, kind=MSO_SHAPE.OVAL)
    text(s, x + 1.08, 1.38, 0.72, 0.72,
         [P(R(str(i + 1), 20, WHITE, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.16, 2.24, 2.63, 0.36,
         [P(R(h, 16.5, NAVY, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.18, 2.64, 2.58, 0.55,
         [P(R(d, 12.5, DGRAY, align=PP_ALIGN.CENTER), ls=1.2)], anchor=MSO_ANCHOR.TOP)
    text(s, x + 0.18, 3.21, 2.58, 0.50,
         [P(R(ex, 10.5, col, True, align=PP_ALIGN.CENTER), ls=1.18)], anchor=MSO_ANCHOR.TOP)
values = [
    ('对用户', '少点几步，常用功能抬手可及', BLUE),
    ('对生态', '公开入口被重新组织，低频功能被看见', TEAL),
    ('对平台', '桌面卡片成为新的入口位', ORANGE),
    ('对系统', '能力目录补充系统意图与场景服务', PURPLE),
]
for i, (h, d, col) in enumerate(values):
    x = 0.45 + i * 3.13
    box(s, x, 3.92, 2.95, 1.32, fill=WHITE, line=BORDER, lw=1.1)
    bar(s, x, 3.92, 0.09, 1.32, col)
    text(s, x + 0.22, 4.04, 2.58, 0.32,
         [P(R(h, 14.5, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.22, 4.42, 2.58, 0.72,
         [P(R(d, 12, DGRAY), ls=1.18)], anchor=MSO_ANCHOR.TOP)
box(s, 0.45, 5.44, 12.25, 0.78, fill=XLBLUE, line=BORDER, lw=1.0)
text(s, 0.62, 5.44, 11.95, 0.78,
     [P(R('面向未来：', 13.5, ORANGE, True),
        R('更多 App、更多设备、更多场景信号；能力目录可以持续扩展，接入系统意图与全局搜索。',
          13.5, NAVY, True), ls=1.2)], anchor=MSO_ANCHOR.MIDDLE)
banner(s, [R('让每一个被埋没的功能，都', 15.5, WHITE, True),
           R('重新被看见', 16.5, YELLOW, True), R('。', 15.5, WHITE, True)])

# ================================================================ 12 summary & outlook
s = prs.slides.add_slide(BLANK)
title(s, '总结与展望 —— 从一张卡片到能力生态')
beihang(s)
text(s, 0.45, 1.12, 5.9, 0.42,
     [P(R('现在：产品闭环', 18, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
bar(s, 0.45, 1.56, 1.10, 0.05, TEAL)
now = [
    '能力聚合：公开入口汇成统一能力目录',
    '入口验证：真机可打开才进入目录',
    '卡片呈现：桌面卡片 / 搜索 / 分类 / 设置',
    '一键直达：单一 Want，失败即报告',
]
paras = []
for d in now:
    paras.append(P(R('✓  ', 14, TEAL, True), R(d, 14.5, DGRAY), ls=1.3, before=14))
text(s, 0.45, 1.82, 5.85, 3.30, paras)
text(s, 6.95, 1.12, 5.9, 0.42,
     [P(R('未来：应用与生态', 18, NAVY, True))], anchor=MSO_ANCHOR.MIDDLE)
bar(s, 6.95, 1.56, 1.10, 0.05, ORANGE)
future = [
    '应用前景：覆盖更多 App、系统意图与设备场景',
    '场景智能：时间、地点、设备状态进入推荐',
    '数字包容：长辈模式、无障碍与按需简化',
    '系统接入：能力目录对接系统意图与全局搜索',
    '生态开放：沉淀能力接入规范，向开发者开放',
]
paras = []
for d in future:
    paras.append(P(R('→  ', 14, ORANGE, True), R(d, 13.5, DGRAY), ls=1.28, before=11))
text(s, 6.95, 1.82, 5.85, 3.60, paras)
text(s, 0.45, 4.45, 12.25, 0.30,
     [P(R('演进路径', 13, ORANGE, True))], anchor=MSO_ANCHOR.MIDDLE)
road = ['能力扩充', '场景智能', '系统接入', '生态开放']
for i, st in enumerate(road):
    x = 0.45 + i * 3.13
    box(s, x, 4.82, 2.95, 0.54, fill=XLBLUE, line=BORDER, lw=1.0)
    text(s, x, 4.82, 2.95, 0.54,
         [P(R(st, 14, NAVY, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
    if i < 3:
        arrow(s, x + 2.97, 5.00, 0.13, 0.18, fill=MBLUE)
box(s, 0.45, 5.68, 12.25, 0.94, fill=XLBLUE, line=BORDER, lw=1.0)
text(s, 0.65, 5.68, 11.85, 0.94,
     [P(R('App 是容器，功能才是服务；让能力成为系统的一等公民。', 20, NAVY, True,
          align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
banner(s, [R('从一个桌面卡片开始，让 App 的能力真正被用起来。', 15.5, WHITE, True)])

# ================================================================ 13 thanks
s = prs.slides.add_slide(BLANK)
pic(s, 'beihang_logo.png', 11.85, 0.18, 1.0, 1.0)
pic(s, 'logo.png', 5.87, 0.98, 1.60, 1.60)
text(s, 0.8, 3.02, 11.73, 0.90,
     [P(R('谢谢观看', 44, NAVY, True, align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
text(s, 0.8, 4.02, 11.73, 0.50,
     [P(R('星门 StarGate · 跨过 App 的门，一步抵达功能', 19, BLUE, False,
          align=PP_ALIGN.CENTER))], anchor=MSO_ANCHOR.MIDDLE)
bar(s, 5.2, 4.95, 2.9, 0.04, LBLUE)
text(s, 0.8, 5.22, 11.73, 0.40,
     [P(R('开源鸿蒙移动应用创新成果申报', 14, GRAY, False, align=PP_ALIGN.CENTER))],
     anchor=MSO_ANCHOR.MIDDLE)
text(s, 0.8, 5.72, 11.73, 0.40,
     [P(R('2026 年 11 月', 14, GRAY, False, align=PP_ALIGN.CENTER))],
     anchor=MSO_ANCHOR.MIDDLE)

prs.save(OUT)
print('saved', OUT, 'slides:', len(prs.slides))
