/**
 * 视觉改版（2026-11-08）：iOS App Library / 展开文件夹风格的彩色图标 tile 配色。
 *
 * 卡片渲染进程无网络/文件系统，也不能引用第三方 App 图标资源。这里用一组
 * iOS 感的饱和渐变，按功能 id 稳定哈希取色，字形取功能名首字 —— 同一个功能
 * 永远得到同一个 tile，跨刷新不跳色，且完全离线可复现。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动，也能编译进 widgets.abc。
 */

export interface TileGradient {
  start: string;
  end: string;
}

/** 8 组渐变（蓝 / 青 / 绿 / 黄橙 / 粉 / 紫 / 靛 / 玫红），两两之间色相拉开。 */
const TILES: TileGradient[] = [
  { start: '#4F8CFF', end: '#2E5BE6' }, // 蓝
  { start: '#45D6D0', end: '#1AA8B8' }, // 青
  { start: '#6BD66B', end: '#2FA84F' }, // 绿
  { start: '#FFC24B', end: '#FF7A45' }, // 黄橙
  { start: '#FF8FB1', end: '#F0548E' }, // 粉
  { start: '#B08CFF', end: '#7A4DE0' }, // 紫
  { start: '#6E86FF', end: '#4A46C8' }, // 靛
  { start: '#FF7D7D', end: '#E0455F' }  // 玫红
];

export const TILE_COUNT: number = TILES.length;

/** 环境渐变（磨砂玻璃底上的柔光）。
 *  2026-11-08 改版：对齐参考图的 iOS App Library 蓝→青→蓝绿壁纸语汇，
 *  替换旧的紫→粉渐变（用户明确指出太丑）。暗色是同色系的深版而非反相。 */
const AMBIENT_LIGHT: string[] = ['#4A8FD4', '#54B0C4', '#79C7B0'];
const AMBIENT_DARK: string[] = ['#223A5E', '#265A72', '#2F6E6A'];

/** 简单稳定字符串哈希（FNV-1a 变体），避免用 Math.random 造成跳色。 */
function hash(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export class CardPalette {
  /** 同一 id → 同一渐变；不同 id 尽量铺开不同颜色。 */
  static tileFor(id: string): TileGradient {
    const i = hash(id || 'x') % TILE_COUNT;
    return { start: TILES[i].start, end: TILES[i].end };
  }

  /** 图标字形：功能名首字；空标签退化为一个点。 */
  static glyphOf(label: string): string {
    return label && label.length > 0 ? label.charAt(0) : '·';
  }

  /** 三段环境渐变色（供 linearGradient 的 colors 使用）。 */
  static ambient(dark: boolean): string[] {
    return (dark ? AMBIENT_DARK : AMBIENT_LIGHT).slice();
  }
}

export default CardPalette;
