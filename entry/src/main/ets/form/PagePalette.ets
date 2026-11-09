import { GlassStyle } from './GlassStyle';
import type { GlassTokens } from './GlassStyle';

/**
 * 精准复刻参考图（2026-11-08）：首页卡片 + 搜索页 + 分类页 + 配置页风格统一对齐。
 *
 * 上一版三个内页用深藏青壁纸（#223A5E / #265A72 / #2F6E6A）和深色磨砂，
 * 与参考图的「蓝→青→蓝绿柔光浅色壁纸 + 15% 白玻璃框」不符。这里所有框体 /
 * 壁纸 token 统一从 GlassStyle.active() 派生（单一真源），保证三版比例迭代
 * 时内页与卡片同步，不会出现各页各写一套 hex 导致风格不对齐。
 *
 * 结构语汇：外层「文件夹框」（15% 白 + 亮白细边 + 大圆角）内嵌「功能图标框」，
 * 绝不用普通列表。所有 8 位 hex 为 AARRGGBB（alpha 在首位，见 D3）。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动。
 */
const G: GlassTokens = GlassStyle.active();

/** 页面背景：iOS App Library 蓝→青→蓝绿浅色壁纸（与卡片 GlassStyle 同源）。 */
export const PAGE_BG: string[] = [G.wallpaper[0], G.wallpaper[1], G.wallpaper[2]];

/** 外层文件夹框：15% 白填充 + 亮白细边 + 大圆角（嵌套框结构的外层）。 */
export const FRAME_BG: string = G.frameBg;
export const FRAME_BORDER: string = G.frameBorder;
export const FRAME_RADIUS: number = G.radiusFrame;

/** 内层功能图标框：略高一档白填充 + 细边 + 中圆角。 */
export const TILE_BG: string = G.tileBg;
export const TILE_BORDER: string = G.tileBorder;
export const TILE_RADIUS: number = G.radiusTile;
export const TILE_SIZE: number = G.tileSize;
export const TILE_GAP: number = G.tileGap;
export const FRAME_GAP: number = G.frameGap;

/** 兼容旧引用名的磨砂玻璃面板底（现统一为外层框 token）。 */
export const GLASS_BG: string = G.frameBg;
export const GLASS_BG_STRONG: string = '#40FFFFFF';
export const GLASS_BORDER: string = G.frameBorder;

/** 文字：纯白主文 + 半透明白次文（alpha 在首位）。 */
export const TEXT_PRIMARY: string = G.textPrimary;
export const TEXT_SECONDARY: string = G.textSecondary;
export const TEXT_TERTIARY: string = '#CCFFFFFF';

/** 强调色（失败/计数等）。 */
export const ACCENT_RED: string = '#FF6B6B';

/** inner 阴影让白色文字在浅色渐变上仍清晰。 */
export const LABEL_SHADOW_COLOR: string = '#80000000';

export class PagePalette {
  static readonly BG: string[] = PAGE_BG;
  static readonly GLASS: string = GLASS_BG;
  static readonly GLASS_STRONG: string = GLASS_BG_STRONG;
  static readonly BORDER: string = GLASS_BORDER;
  static readonly TEXT: string = TEXT_PRIMARY;
  static readonly TEXT_SUB: string = TEXT_SECONDARY;
  static readonly TEXT_DIM: string = TEXT_TERTIARY;
  static readonly RED: string = ACCENT_RED;
  static readonly GREEN: string = '#FF2E8B57';
  static readonly BLUE: string = '#FF247BAA';
  static readonly PURPLE: string = '#FF7650A8';
  static readonly ORANGE: string = '#FFB46A2C';
  static readonly SHADOW: string = LABEL_SHADOW_COLOR;
  /** 嵌套框 token（内页与卡片统一）。 */
  static readonly FRAME_BG: string = FRAME_BG;
  static readonly FRAME_BORDER: string = FRAME_BORDER;
  static readonly FRAME_RADIUS: number = FRAME_RADIUS;
  static readonly TILE_BG: string = TILE_BG;
  static readonly TILE_BORDER: string = TILE_BORDER;
  static readonly TILE_RADIUS: number = TILE_RADIUS;
  static readonly TILE_SIZE: number = TILE_SIZE;
  static readonly TILE_GAP: number = TILE_GAP;
  static readonly FRAME_GAP: number = FRAME_GAP;
}

export default PagePalette;
