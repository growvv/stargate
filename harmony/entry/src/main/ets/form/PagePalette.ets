/**
 * 内页配色（2026-11-11 用户第二次真机反馈后定稿）。
 *
 * 用户原话：「文字还是白色好看，背景的话，稍微用个透明的，或者毛玻璃的，跟
 * 白色有一点对比度就行了。但也不能是纯透明的纯白吧？我白色我就看不见了。」
 *
 * 所以定稿为：**白字 + 中性灰蓝柔光底 + 白玻璃面板**。
 *  - 底色是中性的灰蓝渐变（无饱和色相），比纯白深一档，白字压上去有对比度；
 *    既不是之前那条过深的饱和蓝壁纸，也不是会让白字消失的纯白；
 *  - 面板是 15% 白玻璃 + 40% 白细边，叠在灰底上就是磨砂玻璃质感；
 *  - 文字恢复纯白，层级用 alpha 区分；浅灰底上再补一层柔和黑影保证可读。
 *
 * 尺寸（搜索框高度、字号、图标边长）**不在这里写死** —— 见 PageMetrics，
 * 全部按容器实际宽度推导，手机 / 平板 / 分屏共用一份代码。
 *
 * 所有 8 位 hex 均为 AARRGGBB（alpha 在首位，见 D3）。纯逻辑、无 SDK 依赖，
 * 可被 Node 单测直接驱动。
 */

/** 内页底色：中性灰蓝柔光渐变（三段色相一致，只有明度差）。 */
export const PAGE_BG: string[] = ['#8E99A8', '#7F8B9B', '#727E8F'];

/** 外层面板：15% 白玻璃 + 40% 白细边 + 大圆角。 */
export const FRAME_BG: string = '#26FFFFFF';
export const FRAME_BORDER: string = '#66FFFFFF';
export const FRAME_RADIUS: number = 22;

/** 内层功能框：20% 白 + 30% 白边（比外框亮一档，形成嵌套层次）。 */
export const TILE_BG: string = '#33FFFFFF';
export const TILE_BORDER: string = '#4DFFFFFF';
export const TILE_RADIUS: number = 14;
/** 兜底边长；实际值由 PageMetrics 按容器宽度推导后传入。 */
export const TILE_SIZE: number = 60;
export const TILE_GAP: number = 8;
export const FRAME_GAP: number = 12;

/** 兼容旧引用名的磨砂玻璃面板底（现统一为外层框 token）。 */
export const GLASS_BG: string = FRAME_BG;
export const GLASS_BG_STRONG: string = '#40FFFFFF';
export const GLASS_BORDER: string = FRAME_BORDER;

/** 文字：纯白主文 + 两档 alpha 次文。 */
export const TEXT_PRIMARY: string = '#FFFFFFFF';
export const TEXT_SECONDARY: string = '#D9FFFFFF';
export const TEXT_TERTIARY: string = '#99FFFFFF';

/** 强调色（失败/计数等）。 */
export const ACCENT_RED: string = '#FFFF6B6B';

/** 分隔线：20% 白（灰底上的细线）。 */
export const DIVIDER: string = '#33FFFFFF';

/** 文字阴影：中灰底上的白字需要一层柔和黑影才够清晰。 */
export const LABEL_SHADOW_COLOR: string = '#66000000';

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
  static readonly DIVIDER: string = DIVIDER;
  /** 嵌套框 token（内页统一）。 */
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
