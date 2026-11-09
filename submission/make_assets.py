# -*- coding: utf-8 -*-
"""Generate competition assets: cropped screenshots, logo, diagrams."""
import os, math
from PIL import Image, ImageDraw, ImageFilter
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from matplotlib.font_manager import FontProperties

BASE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.join(BASE, 'assets', 'shots')
ASSETS = os.path.join(BASE, 'assets')
os.makedirs(ASSETS, exist_ok=True)

NAVY = '#1F3864'
BLUE = '#2E75B6'
LBLUE = '#DEEBF7'
MBLUE = '#5B9BD5'
CYAN = '#00B0F0'
TEAL = '#2F9E8F'
ORANGE = '#ED7D31'
RED = '#C00000'
GREEN = '#548235'
GRAY = '#595959'
LGRAY = '#F2F2F2'
WHITE = '#FFFFFF'

FONT_R = 'C:/Windows/Fonts/msyh.ttc'
FONT_B = 'C:/Windows/Fonts/msyhbd.ttc'

def fp(size, bold=False):
    return FontProperties(fname=FONT_B if bold else FONT_R, size=size)

def rounded(im, radius=44, shadow=True, pad=46, bg=(255, 255, 255, 0)):
    w, h = im.size
    if shadow:
        canvas = Image.new('RGBA', (w + pad * 2, h + pad * 2), bg)
        sh = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(sh)
        d.rounded_rectangle([pad, pad + 14, pad + w, pad + h + 14], radius=radius, fill=(0, 0, 0, 90))
        sh = sh.filter(ImageFilter.GaussianBlur(18))
        canvas.alpha_composite(sh)
        mask = Image.new('L', (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=radius, fill=255)
        canvas.paste(im, (pad, pad), mask)
        return canvas
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=radius, fill=255)
    out = Image.new('RGBA', (w, h), bg)
    out.paste(im, (0, 0), mask)
    return out

def crop_shot(src, box, out, radius=44):
    im = Image.open(os.path.join(SHOTS, src)).convert('RGB')
    im = im.crop(box)
    rounded(im, radius).save(os.path.join(ASSETS, out))

# --- screenshots ---------------------------------------------------------
crop_shot('current2.jpeg', (215, 105, 1385, 1185), 'card_widget.png', 42)
crop_shot('current2.jpeg', (0, 0, 1600, 2560), 'desktop_full.png', 0)
crop_shot('all.jpeg', (0, 105, 1600, 2488), 'shot_all.png', 48)
crop_shot('search-a.jpeg', (0, 105, 1600, 980), 'shot_search.png', 40)
crop_shot('explorer.jpeg', (0, 105, 1600, 2488), 'shot_explorer.png', 48)
crop_shot('config.jpeg', (0, 105, 1600, 2488), 'shot_config.png', 48)
crop_shot('category.jpeg', (0, 105, 1600, 2488), 'shot_category.png', 48)
crop_shot('current2.jpeg', (0, 105, 1600, 2488), 'shot_desktop.png', 48)
# compact 4:3-ish crops for the four-entry product slide
crop_shot('all.jpeg', (0, 105, 1600, 1560), 'shot_all_card.png', 40)
crop_shot('category.jpeg', (0, 105, 1600, 1560), 'shot_category_card.png', 40)
crop_shot('explorer.jpeg', (0, 105, 1600, 1560), 'shot_explorer_card.png', 40)
crop_shot('config.jpeg', (0, 105, 1600, 1560), 'shot_config_card.png', 40)

# --- logo ---------------------------------------------------------------
def gradient_disc(size=1024):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = int(size * 0.20)
    for i in range(size):
        t = i / (size - 1)
        c = (int(31 + (0x2E - 31) * t), int(56 + (0x9B - 56) * t), int(100 + (0xE6 - 100) * t), 255)
        d.line([(0, i), (size, i)], fill=c)
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    im.putalpha(mask)
    d = ImageDraw.Draw(im)
    for wdt, alpha in [(int(size * 0.045), 70), (int(size * 0.018), 255)]:
        pad = int(size * 0.18)
        d.ellipse([pad, pad, size - pad, size - pad], outline=(255, 255, 255, alpha), width=wdt)
    d.arc([int(size * 0.10), int(size * 0.10), int(size * 0.90), int(size * 0.90)], 205, 335,
          fill=(120, 230, 255, 255), width=int(size * 0.018))
    cx, cy = size * 0.5, size * 0.5
    R, r2 = size * 0.215, size * 0.065
    pts = []
    for k in range(8):
        ang = -math.pi / 2 + k * math.pi / 4
        rr = R if k % 2 == 0 else r2
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.polygon(pts, fill=(255, 255, 255, 255))
    d.ellipse([size * 0.735, size * 0.20, size * 0.785, size * 0.25], fill=(120, 230, 255, 255))
    return im

gradient_disc().save(os.path.join(ASSETS, 'logo.png'))

# --- matplotlib diagrams ------------------------------------------------
def canvas(w=13.333, h=7.5, dpi=220):
    fig = plt.figure(figsize=(w, h), dpi=dpi)
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, w)
    ax.set_ylim(0, h)
    ax.axis('off')
    fig.patch.set_facecolor('white')
    return fig, ax

def box(ax, x, y, w, h, text, fc=WHITE, ec=BLUE, tc=NAVY, size=11, bold=False,
        radius=0.10, lw=1.4, align='center', va='center', alpha=1.0):
    p = FancyBboxPatch((x, y), w, h, boxstyle=f"round,pad=0.02,rounding_size={radius}",
                       linewidth=lw, edgecolor=ec, facecolor=fc, alpha=alpha, zorder=2)
    ax.add_patch(p)
    ha = {'center': 'center', 'left': 'left'}[align]
    tx = x + w / 2 if align == 'center' else x + 0.13
    ax.text(tx, y + h / 2, text, ha=ha, va=va, fontproperties=fp(size, bold),
            color=tc, zorder=3, linespacing=1.25)

def arrow(ax, x1, y1, x2, y2, color=BLUE, lw=1.8, style='-|>', ms=14, rad=0.0):
    a = FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style, mutation_scale=ms,
                        linewidth=lw, color=color, connectionstyle=f"arc3,rad={rad}",
                        shrinkA=2, shrinkB=2, zorder=1)
    ax.add_patch(a)

def label(ax, x, y, text, size=13, bold=True, color=NAVY, ha='left', va='center'):
    ax.text(x, y, text, ha=ha, va=va, fontproperties=fp(size, bold), color=color, zorder=5)

# architecture
fig, ax = canvas()
layers = [
    ('入口层', 5.62, ['桌面卡片 4×4', '全部功能 A–Z', '分类页', '搜索', '能力探索', '设置']),
    ('编排层', 4.32, ['CardBinding', 'WidgetCardData', 'RefreshOrchestrator', 'PageRouter', 'LaunchDispatcher']),
    ('能力层', 3.02, ['RankingEngine', 'RecentAdditions', 'SearchFilter /\nPinyinUtil', 'LetterSections', 'CategoryOrder', 'CapabilityExplorer']),
    ('数据层', 1.72, ['CapabilityRepository', 'EffectiveCatalog', 'InstallSnapshot', 'UsageStore', 'CategoryOrderStore', 'DiscoveryCandidate\nCatalog']),
    ('系统层', 0.42, ['FormExtensionAbility', 'UIAbility', 'Preferences', 'bundleManager.\ncanOpenLink', 'startAbility']),
]
colors = [BLUE, MBLUE, TEAL, '#7F9FBF', NAVY]
for idx, (name, y, items) in enumerate(layers):
    ax.add_patch(FancyBboxPatch((0.28, y - 0.12), 12.78, 1.12, boxstyle="round,pad=0.01,rounding_size=0.12",
                                linewidth=0, facecolor='#F7FAFD' if idx % 2 == 0 else '#EEF5FB', zorder=0))
    box(ax, 0.36, y + 0.04, 1.18, 0.80, name, fc=colors[idx], ec=colors[idx], tc='white', size=12, bold=True)
    n = len(items)
    gap = 0.13
    left = 1.74
    total = 12.24 - left
    bw = (total - gap * (n - 1)) / n
    for j, it in enumerate(items):
        x = left + j * (bw + gap)
        box(ax, x, y + 0.07, bw, 0.74, it, fc='white', ec=colors[idx], tc=NAVY,
            size=8.6 if n > 4 else 10.5, lw=1.2)
for y1, y2 in [(5.62, 4.32), (4.32, 3.02), (3.02, 1.72), (1.72, 0.42)]:
    arrow(ax, 6.66, y1 - 0.12, 6.66, y2 + 1.02, color=MBLUE, lw=2.2, ms=13)
ax.add_patch(FancyBboxPatch((0.28, 6.86), 12.78, 0.42, boxstyle="round,pad=0.01,rounding_size=0.10",
                            linewidth=0, facecolor=LBLUE, zorder=0))
label(ax, 0.48, 7.07, '分层解耦：入口 / 编排 / 能力 / 数据 / 系统，五层单向依赖', size=12.5, color=NAVY)
label(ax, 12.95, 7.07, '纯逻辑可单测', size=11, color=BLUE, ha='right')
fig.savefig(os.path.join(ASSETS, 'arch.png'), facecolor='white')
plt.close(fig)

# distribution / data flow
fig, ax = canvas()
srcs = [('能力库 capabilities.json\n74 项原子能力', 5.55), ('应用模板与安装探测\n48 个 App', 4.10),
        ('发现候选目录\nREA / UI Test / 人工', 2.65), ('用户行为与配置\n用量 / 分类顺序', 1.20)]
for text, y in srcs:
    box(ax, 0.32, y, 2.75, 1.05, text, fc='white', ec=BLUE, tc=NAVY, size=10.5)
    arrow(ax, 3.07, y + 0.52, 3.48, y + 0.52, color=MBLUE)
box(ax, 3.52, 3.55, 2.55, 2.45,
    '统一能力目录\n\nEffectiveCatalog\n安装状态过滤\n证据等级标注\n分类 / 路由 / 标识', fc='#EAF3FB', ec=BLUE, tc=NAVY, size=11.5, bold=False)
box(ax, 6.35, 4.00, 1.75, 1.55, '智能分发\n\n排序 / 搜索\n分组 / 去重', fc=BLUE, ec=BLUE, tc='white', size=11.5, bold=True)
arrow(ax, 6.07, 4.77, 6.35, 4.77, color=BLUE)
outs = [('桌面卡片\n推荐 / 最近添加 / 分类', 5.95), ('全部功能\nA–Z / 搜索 / 取消', 4.55),
        ('分类页\n该类目全部能力', 3.15), ('能力探索\n证据等级 / 打开 ›', 1.75)]
for text, y in outs:
    box(ax, 8.55, y, 2.72, 0.98, text, fc='white', ec=TEAL, tc=NAVY, size=10)
    if y > 2.0:
        arrow(ax, 8.10, y + 0.49, 8.55, y + 0.49, color=TEAL)
box(ax, 6.35, 1.55, 1.75, 0.95, 'LaunchDispatcher\n单一 Want', fc='#EAF3FB', ec=BLUE, tc=NAVY, size=9.5)
arrow(ax, 8.10, 1.95, 8.55, 1.95, color=TEAL)
arrow(ax, 8.55, 2.38, 8.10, 2.16, color=BLUE)
box(ax, 8.55, 0.55, 2.72, 0.95, '目标 App 功能页\nScheme / Deep Link / Shortcut', fc=NAVY, ec=NAVY, tc='white', size=9.5, bold=True)
arrow(ax, 7.22, 1.55, 8.55, 1.03, color=NAVY)
arrow(ax, 9.9, 0.55, 1.70, 1.20, color=ORANGE, lw=1.4, style='-|>', ms=12, rad=-0.12)
label(ax, 5.55, 0.28, '使用反馈 → 用量快照 → 排序更新；安装探测 → 最近添加；配置拖动 → 分类顺序', size=10.5, color=ORANGE, ha='center')
fig.savefig(os.path.join(ASSETS, 'flow.png'), facecolor='white')
plt.close(fig)

# route exploration 4 lanes
fig, ax = canvas()
lanes = [
    ('A 应用内快捷方式', '长按 App', '系统 Shortcut', '指定功能页', BLUE),
    ('B 链接路由', '链接 / 二维码 / 卡片', 'App Linking / Scheme', '功能页', TEAL),
    ('C 系统选择器', '能力请求', '系统选应用', '系统分发', ORANGE),
    ('D 静态分析 + 测试', 'HAP / 资源 / 代码', 'REA / UI Test 线索', '人工确认', '#7F5FA8'),
]
for i, (name, s1, s2, s3, col) in enumerate(lanes):
    y = 5.55 - i * 1.25
    box(ax, 0.30, y - 0.02, 2.55, 0.82, name, fc=col, ec=col, tc='white', size=11.5, bold=True)
    box(ax, 3.00, y, 2.35, 0.78, s1, fc='white', ec=col, tc=NAVY, size=9.5)
    box(ax, 5.50, y, 2.55, 0.78, s2, fc='white', ec=col, tc=NAVY, size=9.5)
    box(ax, 8.20, y, 2.10, 0.78, s3, fc='white', ec=col, tc=NAVY, size=9.5)
    if i < 3:
        arrow(ax, 2.85, y + 0.39, 3.00, y + 0.39, color=col)
    arrow(ax, 5.35, y + 0.39, 5.50, y + 0.39, color=col)
    arrow(ax, 8.05, y + 0.39, 8.20, y + 0.39, color=col)
    arrow(ax, 10.30, y + 0.39, 10.55, y + 0.39, color=col)
box(ax, 10.55, 1.55, 2.45, 4.55,
    '证据分级\n\n已验证直达\nREA 线索\nUI Test 候选\n人工确认', fc='#F2F7FC', ec=NAVY, tc=NAVY, size=10.5)
box(ax, 0.30, 0.45, 3.0, 0.95, '生产准入：只分发已验证入口', fc=NAVY, ec=NAVY, tc='white', size=10.5, bold=True)
box(ax, 3.55, 0.45, 3.0, 0.95, '统一能力目录 + 智能排序', fc=BLUE, ec=BLUE, tc='white', size=10.5, bold=True)
box(ax, 6.80, 0.45, 2.9, 0.95, '卡片 / 列表 / 搜索 / 探索', fc=TEAL, ec=TEAL, tc='white', size=10.5, bold=True)
box(ax, 9.95, 0.45, 3.05, 0.95, '一键直达目标功能页', fc=ORANGE, ec=ORANGE, tc='white', size=10.5, bold=True)
for x1, x2 in [(3.30, 3.55), (6.55, 6.80), (9.70, 9.95)]:
    arrow(ax, x1, 0.92, x2, 0.92, color=NAVY, lw=2.0)
fig.savefig(os.path.join(ASSETS, 'routes.png'), facecolor='white')
plt.close(fig)

# ranking weights chart
fig, ax = canvas(w=6.2, h=4.6, dpi=220)
weights = [('当日使用', 0.30), ('当月使用', 0.20), ('时间衰减', 0.18), ('时段偏好', 0.12),
           ('场景亲和', 0.08), ('最近序列', 0.07), ('置信度', 0.05)]
ys = list(range(len(weights)))[::-1]
vals = [w[1] for w in weights]
names = [w[0] for w in weights]
colors2 = ['#9DC3E6'] * len(vals)
for k in (0, 1, 2):
    colors2[k] = BLUE
bars = ax.barh(ys, vals, color=colors2, height=0.56)
for y, v in zip(ys, vals):
    ax.text(v + 0.007, y, f'{v:.2f}', va='center',
            fontproperties=fp(10, True), color=NAVY)
for y, name in zip(ys, names):
    ax.text(-0.015, y, name, transform=ax.get_yaxis_transform(), ha='right',
            va='center', fontproperties=fp(11, True), color=NAVY, clip_on=False)
ax.set_xlim(0, 0.37)
ax.set_ylim(-0.7, len(weights) - 0.3)
ax.set_yticks([])
ax.set_xticks([])
for s in ax.spines.values():
    s.set_visible(False)
fig.savefig(os.path.join(ASSETS, 'ranking.png'), facecolor='white',
            bbox_inches='tight', pad_inches=0.10)
plt.close(fig)

print('assets ready:', sorted(os.listdir(ASSETS)))
