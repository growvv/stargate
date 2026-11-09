/**
 * D3 修复（真机 2026-11-07）：ArkUI 的 8 位 hex 颜色是 **AARRGGBB**，不是 CSS 的
 * RGBA。旧值 '#ffffff30' 被读成 rgba(255,255,48,1) —— 不透明亮黄，导致卡片
 * updateForm 后整块变黄、全量/分类/配置页的搜索框也一直是黄，白字对比度极差。
 *
 * 这里统一以「alpha 在首位」生成 token，所有消费方（ThemeTokens / 各页面 /
 * WidgetCard storage 默认值）只用本模块导出的常量，禁止再手写 8 位 hex。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动，也能编译进 widgets.abc。
 */

/** 单个通道 → 两位小写 hex（不足补零）。 */
function channel(v: number): string {
  const n = Math.max(0, Math.min(255, Math.round(v)));
  const s = n.toString(16);
  return s.length < 2 ? '0' + s : s;
}

export interface ThemeColorSet {
  cardBg: string;
  cardBgNoBlur: string;
  borderColor: string;
  textPrimary: string;
  textSecondary: string;
  divider: string;
}

/** 生成 AARRGGBB 字符串。a/r/g/b 均取 0–255。 */
export function hex8(r: number, g: number, b: number, a: number): string {
  return '#' + channel(a) + channel(r) + channel(g) + channel(b);
}

/** 亮色主题（IOS_VISUAL_SPEC）：半透明白材质 + 白色文字，alpha 在首位。 */
export const LIGHT: ThemeColorSet = {
  cardBg: hex8(255, 255, 255, 0x30),        // rgba(255,255,255,0.19)
  cardBgNoBlur: hex8(255, 255, 255, 0x4d), // blur 不可用时略实一些
  borderColor: hex8(255, 255, 255, 0x55),
  textPrimary: '#ffffff',
  // 截图复看：玻璃底上的图标标签/副标题需要更高对比度
  textSecondary: hex8(255, 255, 255, 0xf2),
  divider: hex8(255, 255, 255, 0x55)
};

/** 暗色主题：独立设计，不是简单反相。 */
export const DARK: ThemeColorSet = {
  cardBg: hex8(0, 0, 0, 0x30),            // rgba(0,0,0,0.19)
  cardBgNoBlur: hex8(0, 0, 0, 0x4d),
  borderColor: hex8(255, 255, 255, 0x33),
  textPrimary: '#ffffff',
  textSecondary: hex8(255, 255, 255, 0xe6),
  divider: hex8(255, 255, 255, 0x33)
};

/** 命名空间门面（测试与 ArkTS 静态调用都友好）。 */
export class ThemeColors {
  static hex8: (r: number, g: number, b: number, a: number) => string = hex8;
  static LIGHT: ThemeColorSet = LIGHT;
  static DARK: ThemeColorSet = DARK;
}

export default ThemeColors;
