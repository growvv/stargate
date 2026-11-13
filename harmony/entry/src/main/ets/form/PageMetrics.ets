/**
 * 内页尺寸推导（2026-11-11 用户反馈后新增）。
 *
 * 用户原话：「你写这些 UI 上面的写法，尽量不要用绝对的，不然的话后面会换到
 * 平板上，可能就不是很兼容平板」。
 *
 * 之前搜索框写死 height(46) / fontSize(16) / borderRadius(23)，分类页图标写死
 * 60vp —— 在 375vp 的手机上刚好，换到 800vp 的平板就是一个又小又挤的搜索框，
 * 和一张 60vp 的小图标网格。这里改成**按容器实际宽度推导**：
 *  - 页面在 onAreaChange 里把真实宽度（vp）交给 compute()，分屏、折叠屏展开、
 *    平板横竖屏都会拿到不同的宽度，同一份代码自适应；
 *  - 所有尺寸都乘同一个缩放系数 k = 宽度 / 设计基准宽度，并各自钳制上下限；
 *  - 分类页图标网格按「一行 4 个、扣掉全部留白后均分」算，不写死边长。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动。
 */

/** 设计基准宽度（vp）：iPhone 级别手机的逻辑宽度，也是 CardLayout 的参照。 */
const DESIGN_WIDTH: number = 390;

/** 推导结果（全部 vp）。 */
export interface PageMetrics {
  /** 参与推导的容器宽度（vp）。 */
  widthVp: number;
  /** 搜索胶囊高度。 */
  searchHeight: number;
  /** 搜索框字号 / 占位符字号。 */
  searchFont: number;
  /** 搜索胶囊圆角（= 高度的一半，保持胶囊形）。 */
  searchRadius: number;
  /** 搜索胶囊左右内边距。 */
  searchPadX: number;
  /** 搜索图标边长。 */
  searchIconSize: number;
  /** 页面大标题字号。 */
  titleFont: number;
  /** 列表主文字号。 */
  rowFont: number;
  /** 列表次文字号。 */
  rowSubFont: number;
  /** 列表行内图标边长。 */
  rowIconSize: number;
  /** 分类页功能图标边长（一行 4 个均分）。 */
  tileSize: number;
  /** 分类页外层框左右内边距（与 tileSize 同一套推导，页面必须用这个值）。 */
  framePad: number;
  /** 分类页图标之间的横向间距（同上）。 */
  tileGap: number;
  /** 分类页功能图标圆角。 */
  tileRadius: number;
  /** 页面左右留白。 */
  pagePad: number;
  /** 列表右侧给 A–Z 索引条留的宽度。 */
  indexWidth: number;
}

function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : (v > hi ? hi : v);
}

/** 无实测宽度时的兜底（手机基准）。 */
const FALLBACK_WIDTH: number = DESIGN_WIDTH;

export class PageMetricsCalc {
  /**
   * 由容器宽度推导整套内页尺寸。
   * @param widthVp 容器实际宽度（vp）；<= 0 时按手机基准。
   */
  static compute(widthVp: number): PageMetrics {
    const w: number = widthVp > 0 ? widthVp : FALLBACK_WIDTH;
    // 缩放系数：以 390vp 为 1.0，钳在 [0.85, 1.75]。
    // 上限防止平板把字号放到夸张；下限保证小屏（如 320vp）不至于挤成一团。
    const k: number = clamp(w / DESIGN_WIDTH, 0.85, 1.75);

    const pagePad: number = Math.round(clamp(w * 0.046, 14, 40));
    const searchHeight: number = Math.round(clamp(46 * k, 40, 72));
    const searchFont: number = Math.round(clamp(16 * k, 14, 24) * 10) / 10;
    const rowIconSize: number = Math.round(clamp(46 * k, 40, 72));

    // 分类页：一行 4 个图标。宽度扣掉页面留白、外框内边距、图标之间的间距后均分。
    const framePad: number = Math.round(clamp(14 * k, 10, 26));
    const tileGap: number = Math.round(clamp(8 * k, 6, 18));
    const usable: number = w - pagePad * 2 - framePad * 2 - tileGap * 3;
    // 一行 4 个必须装得下：上限 120 防止大平板图标夸张，下限 36 只防负数，
    // 真正的下限由 usable/4 决定 —— 宁可图标小一点，也不允许横向溢出。
    // 用 floor 而不是 round：宁可少半 vp，也不允许 4 个图标横向溢出。
    const tileSize: number = Math.floor(clamp(usable / 4, 36, 120));

    const metrics: PageMetrics = {
      widthVp: Math.round(w),
      searchHeight: searchHeight,
      searchFont: searchFont,
      // 胶囊圆角恒等于高度的一半：无论多高都保持两端半圆。
      searchRadius: Math.round(searchHeight / 2),
      searchPadX: Math.round(clamp(searchHeight * 0.35, 12, 26)),
      searchIconSize: Math.round(clamp(searchHeight * 0.42, 16, 30)),
      titleFont: Math.round(clamp(34 * k, 28, 48)),
      rowFont: Math.round(clamp(16 * k, 15, 24)),
      rowSubFont: Math.round(clamp(11.5 * k, 11, 17) * 10) / 10,
      rowIconSize: rowIconSize,
      tileSize: tileSize,
      framePad: framePad,
      tileGap: tileGap,
      tileRadius: Math.round(clamp(tileSize * 0.24, 10, 28)),
      pagePad: pagePad,
      // A–Z 索引条按缩放走，但至少留 22vp 手指宽度。
      indexWidth: Math.round(clamp(22 * k, 22, 34))
    };
    return metrics;
  }

  /** 手机基准（Node 测试 / 首帧兜底）。 */
  static baseline(): PageMetrics {
    return PageMetricsCalc.compute(FALLBACK_WIDTH);
  }
}

export default PageMetricsCalc;
