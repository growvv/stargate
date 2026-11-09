/**
 * 精准复刻参考图（2026-11-08）：iOS App Library 的「浅色半透明磨砂玻璃 + 嵌套框」。
 *
 * 参考图实测语汇：
 *  - 壁纸是蓝→青→蓝绿柔光渐变（不是深色藏青）；
 *  - 每个分类是一个「外层玻璃文件夹框」：约 15% 白填充 + 1px 亮白细边框 +
 *    内部顶部高光 + 圆角 ~22vp + 柔和外阴影；框下带分类标签；
 *  - 外层框内嵌 2×2 的「功能图标框」，每个功能用独立圆角框划分（嵌套框结构）；
 *  - 绝不用普通列表。
 *
 * 三版比例迭代：VARIANTS 描述「外层框圆角 / 内框尺寸 / 间距」三档密度，
 * 由 ACTIVE_VARIANT 选择；三版逐个真机截图对比后把 ACTIVE_VARIANT 改为最佳版保留。
 *
 * ArkTS 约束：本文件会被编译进卡片 widgets.abc，禁止 object spread / enum /
 * 参数属性 / 结构类型。所有 8 位 hex 均为 AARRGGBB（alpha 在首位，见 D3）。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动。
 */

export interface GlassTokens {
  /** 外层玻璃框填充（AARRGGBB）。 */
  frameBg: string;
  /** 外层框亮白细边（AARRGGBB）。 */
  frameBorder: string;
  /** 内嵌功能图标框填充（AARRGGBB）。 */
  tileBg: string;
  tileBorder: string;
  /** 文字色（AARRGGBB / RGB）。 */
  textPrimary: string;
  textSecondary: string;
  /** 三段壁纸渐变（6 位 RGB）。 */
  wallpaper: string[];
  /** 外框圆角 / 内框圆角（vp）。 */
  radiusFrame: number;
  radiusTile: number;
  /** 内框边长（vp），按 designWidth 720 的 4×4 卡片坐标系。 */
  tileSize: number;
  /** 内层功能框之间的间距（vp）。 */
  tileGap: number;
  /** 外层文件夹框之间的间距（vp）。 */
  frameGap: number;
  /** 一屏显示的外层文件夹框数量。 */
  framesPerScreen: number;
  /** 外层文件夹框的宽高比（三版比例迭代的核心差异）。 */
  frameAspect: number;
}

/** 精确复刻的浅色玻璃 token（参考图基准）。 */
const BASE: GlassTokens = {
  frameBg: '#26FFFFFF',       // 15% 白
  frameBorder: '#8CFFFFFF',   // 55% 亮白细边
  tileBg: '#33FFFFFF',        // 内框 20% 白
  tileBorder: '#66FFFFFF',
  textPrimary: '#FFFFFF',
  textSecondary: '#E6FFFFFF',
  wallpaper: ['#4A8FD4', '#54B0C4', '#79C7B0'],
  radiusFrame: 22,
  radiusTile: 14,
  tileSize: 92,
  tileGap: 8,
  frameGap: 14,
  framesPerScreen: 4,
  frameAspect: 1.0
};

/** 三版比例（全部显式字段，ArkTS 无 object spread）。 */
export const VARIANTS: GlassTokens[] = [
  // V1：紧凑方形（2026-11-09 图标下新增功能名文字，内框缩到 60 以装下两行标签）
  {
    frameBg: '#26FFFFFF', frameBorder: '#8CFFFFFF', tileBg: '#33FFFFFF', tileBorder: '#66FFFFFF',
    textPrimary: '#FFFFFF', textSecondary: '#E6FFFFFF',
    wallpaper: ['#4A8FD4', '#54B0C4', '#79C7B0'],
    radiusFrame: 20, radiusTile: 12, tileSize: 60, tileGap: 4, frameGap: 8, framesPerScreen: 4,
    frameAspect: 0.92
  },
  // V2：参考图比例（内框更大、框间留白舒适）
  {
    frameBg: '#26FFFFFF', frameBorder: '#8CFFFFFF', tileBg: '#33FFFFFF', tileBorder: '#66FFFFFF',
    textPrimary: '#FFFFFF', textSecondary: '#E6FFFFFF',
    wallpaper: ['#4A8FD4', '#54B0C4', '#79C7B0'],
    radiusFrame: 24, radiusTile: 15, tileSize: 96, tileGap: 10, frameGap: 16, framesPerScreen: 4,
    frameAspect: 1.06
  },
  // V3：舒展宽框（内框最大、圆角最柔，接近参考图横向文件夹感）
  {
    frameBg: '#26FFFFFF', frameBorder: '#8CFFFFFF', tileBg: '#33FFFFFF', tileBorder: '#66FFFFFF',
    textPrimary: '#FFFFFF', textSecondary: '#E6FFFFFF',
    wallpaper: ['#4A8FD4', '#54B0C4', '#79C7B0'],
    radiusFrame: 26, radiusTile: 16, tileSize: 108, tileGap: 12, frameGap: 18, framesPerScreen: 4,
    frameAspect: 1.18
  }
];

/** 当前生效的比例版本（三版迭代时 0→1→2，最终保留最佳版）。 */
export const ACTIVE_VARIANT: number = 0;

function copy(t: GlassTokens): GlassTokens {
  const out: GlassTokens = {
    frameBg: t.frameBg, frameBorder: t.frameBorder,
    tileBg: t.tileBg, tileBorder: t.tileBorder,
    textPrimary: t.textPrimary, textSecondary: t.textSecondary,
    wallpaper: [t.wallpaper[0], t.wallpaper[1], t.wallpaper[2]],
    radiusFrame: t.radiusFrame, radiusTile: t.radiusTile,
    tileSize: t.tileSize, tileGap: t.tileGap,
    frameGap: t.frameGap, framesPerScreen: t.framesPerScreen,
    frameAspect: t.frameAspect
  };
  return out;
}

export class GlassStyle {
  /** 取第 n 版比例（0-based，越界钳到合法范围），返回独立副本。 */
  static variant(n: number): GlassTokens {
    const i: number = Math.max(0, Math.min(VARIANTS.length - 1, Math.round(n)));
    return copy(VARIANTS[i]);
  }
  static count(): number { return VARIANTS.length; }
  static base(): GlassTokens { return copy(BASE); }
  /** 当前生效版本（供 CardBinding 把整套 token 推给卡片）。 */
  static active(): GlassTokens { return copy(VARIANTS[ACTIVE_VARIANT]); }
}

export default GlassStyle;
