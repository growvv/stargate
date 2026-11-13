/**
 * 卡片尺寸自适应（2026-11-11，真机手机验证后重写）。
 *
 * 真机缺陷根因：卡片此前把 tileSize / 字号 / 间距全部写死为 720 设计宽下的
 * 固定 vp（V1: tileSize=60），但 4×4 卡片在 1216×2688 手机上的实际尺寸只有
 * 约 326×342vp。固定尺寸的内容总高超过卡片可用高度，而「文件夹框」区域是
 * layoutWeight(1)，内容比分配高度更高时就画到下面的分类 chips 上 ——
 * 真机截图里「推荐 / 最近添加」压住「支付 / 购物」、第二行图标溢出框底。
 *
 * 修复思路：**先量卡片，再算尺寸**。FormAbility 从 onAddForm 的 want 参数里
 * 拿到 ohos.extra.param.key.form_width / form_height（vp），这里据此推导
 * 图标边长、行高、字号、标签行数与 chips 行数，保证内容高度 ≤ 可用高度；
 * 宽度只作为上限（半框宽要放下两个图标）。不同手机 / 平板 / 不同卡片尺寸
 * 都会得到不同结果，同一份代码即可适配，不再依赖某一台设备的像素。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动，也能编译进卡片 widgets.abc。
 */

/** 卡片实测尺寸（**像素**）。未知时传 0，由 compute 回退到设计基准。 */
export interface CardSize {
  widthPx: number;
  heightPx: number;
}

/** 计算输入：尺寸 + 内容规模（分类名决定 chips 行数）。 */
export interface CardLayoutInput {
  size: CardSize;
  /** 屏幕像素密度（vp = px / density）。0 或缺省时按 3.25 估算。 */
  density: number;
  /** 分类 chip 名称（按实际名称估宽，避免长类目多出一行把框挤扁）。 */
  categoryNames: string[];
  /** 外层文件夹框数量（当前为 2：推荐 / 最近添加）。 */
  frameCount: number;
}

/** 卡片布局 token（CardBinding 推给 WidgetCard 的 @LocalStorageProp）。 */
export interface CardLayoutTokens {
  /** 图标边长（vp）。 */
  tileSize: number;
  /** 内层两行之间的行距（vp）。 */
  tileGap: number;
  /** 外层文件夹框之间的间距（vp）。 */
  frameGap: number;
  /** 图标下功能名的字号 / 行高 / 行数。 */
  tileLabelFont: number;
  tileLabelLine: number;
  tileLabelLines: number;
  /** 框下标签（推荐 / 最近添加）字号。 */
  frameLabelFont: number;
  /** 分类 chip 字号与内边距。 */
  chipFont: number;
  chipPadX: number;
  chipPadY: number;
  /** 顶栏标题字号。 */
  titleFont: number;
  /** 实测尺寸（vp，已按屏幕密度换算；供调试与后续版本判断）。 */
  widthVp: number;
  heightVp: number;
  /** 换算所用的屏幕密度。 */
  densityPx: number;
  /** 密度档位：compact / regular / roomy。 */
  density: string;
}

/** 设计基准（4×4 卡片在常见手机上的典型尺寸，实测 Mate 60 约 326×342vp）。 */
const FALLBACK_WIDTH: number = 360;
const FALLBACK_HEIGHT: number = 360;
/** 缺省屏幕密度：Mate 60 实测 1065px / 326vp ≈ 3.27。 */
const FALLBACK_DENSITY: number = 3.25;

/** 卡片内容区左右留白（外层 Flex 的 padding）。 */
const PAGE_PAD: number = 12;
/** 外层框左右内边距。 */
const FRAME_PAD: number = 8;
/** 外层框上下内边距合计（上 8 / 下 10）。 */
const FRAME_PAD_Y: number = 18;
/** 功能名与图标之间的间距。 */
const LABEL_TOP: number = 3;
/** 框下标签占高（字号 13 的行高 + 上间距 4）。 */
const FRAME_LABEL_BLOCK: number = 22;
/**
 * 顶栏占高：上内边距 12 + 标题行（字号 × 1.4）。
 * 用户 2026-11-11 拍板：去掉 StarGate 下面那行小字（「常用功能 · 点图标直达」），
 * 顶栏只剩标题 + 右侧「搜索」按钮，高度因此随标题字号变化，不再分两档。
 */
const HEADER_TOP: number = 12;
/** 文件夹框区域的顶部内边距。 */
const FRAMES_TOP: number = 6;
/** 分隔线（0.5 线宽 + 上下各 3 的 margin）。 */
const DIVIDER: number = 6;
/** 底部情境提示行（11.5 号字 + 下内边距）。 */
const FOOTER: number = 22;
/** 高度安全余量：宁可图标小一点，也不允许内容压到 chips。 */
const SLACK: number = 2;

function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : (v > hi ? hi : v);
}

export class CardLayout {
  /**
   * 由实测尺寸推导整套 token。
   *
   * 高度是主约束：先扣顶栏、chips、留白，剩下的才是文件夹框区域；框内两行
   * 图标 + 功能名 + 框下标签都必须塞进这块高度。宽度只用来卡上限。最后对
   * 结果做上下限钳制，避免极小尺寸算出不可读的字号。
   */
  static compute(input: CardLayoutInput): CardLayoutTokens {
    // 系统在 onAddForm 的 Want 里给的是**像素**（真机实测 1065×1112 px），
    // 而 ArkUI 的 vp 与字号都以 vp 计。必须先用屏幕密度换算，否则会把
    // 一张 326vp 宽的卡片当成 1065vp，算出巨大的图标再被裁掉。
    const density: number = input.density > 0 ? input.density : FALLBACK_DENSITY;
    const widthVp: number = input.size.widthPx > 0 ? input.size.widthPx / density : FALLBACK_WIDTH;
    const heightVp: number = input.size.heightPx > 0 ? input.size.heightPx / density : FALLBACK_HEIGHT;
    const frames: number = input.frameCount > 0 ? input.frameCount : 2;

    // ── 顶栏：只有标题（用户拍板去掉副标题小字） ────────────────────
    const titleFont: number = clamp(Math.round(widthVp / 15), 18, 26);
    const headerH: number = HEADER_TOP + Math.round(titleFont * 1.4);

    // ── chips：按真实类目名做贪心排布，算准行数 ──────────────────────
    const chipFont: number = widthVp >= 340 ? 12.5 : 11.5;
    const chipPadX: number = 10;
    const chipPadY: number = 3;
    const chipAvailW: number = widthVp - 20;
    const chipRows: number = CardLayout.chipRowCount(input.categoryNames, chipFont, chipPadX, chipAvailW);
    // 每个 chip 高 = 字号行高 + 上下内边距 + 下外边距 5。
    const chipRowH: number = chipFont * 1.45 + chipPadY * 2 + 5;
    const chipsH: number = chipRows * chipRowH;

    // ── 文件夹框可用高度 ──────────────────────────────────────────────
    // 顶栏 + 框区上内边距 + chips + 分隔线 + 底部提示，全部是固定开销。
    const frameGap: number = 8;
    const fixedChrome: number = headerH + FRAMES_TOP + chipsH + DIVIDER + FOOTER;
    const framesAreaH: number = heightVp - fixedChrome;

    // ── 宽度上限：半框宽内放两个图标 ─────────────────────────────────
    const frameW: number = (widthVp - PAGE_PAD * 2 - 8) / 2;
    const innerW: number = frameW - FRAME_PAD * 2;
    const widthTile: number = (innerW - 6) / 2;

    // ── 高度上限：两行（图标 + 功能名）+ 框下标签 + 框间距 ────────────
    let lines: number = 2;
    let labelFont: number = widthVp >= 340 ? 10.5 : 10;
    let labelLine: number = labelFont + 2;
    const fixed: number = FRAME_PAD_Y + FRAME_LABEL_BLOCK + frameGap + SLACK;
    const block = (tile: number, ln: number, lh: number): number => {
      return 2 * (tile + LABEL_TOP + ln * lh) + fixed;
    };
    const budget: number = framesAreaH - fixed - 2 * (LABEL_TOP + lines * labelLine);
    let heightTile: number = budget / 2;
    if (heightTile < 52) {
      lines = 1;
      labelFont = 10;
      labelLine = 12;
      heightTile = (framesAreaH - fixed - 2 * (LABEL_TOP + lines * labelLine)) / 2;
    }

    let tileSize: number = Math.floor(Math.min(widthTile, heightTile));
    tileSize = clamp(tileSize, 34, 96);

    // 钳制后再校一次：极端尺寸下按可用高度回收。
    if (block(tileSize, lines, labelLine) > framesAreaH) {
      const fit: number = Math.floor((framesAreaH - fixed -
        2 * (LABEL_TOP + lines * labelLine)) / 2);
      tileSize = clamp(fit, 30, tileSize);
    }

    const densityClass: string = tileSize >= 76 ? 'roomy' : (tileSize >= 52 ? 'regular' : 'compact');

    const tokens: CardLayoutTokens = {
      tileSize: tileSize,
      tileGap: tileSize >= 76 ? 8 : 4,
      frameGap: frameGap,
      tileLabelFont: labelFont,
      tileLabelLine: labelLine,
      tileLabelLines: lines,
      frameLabelFont: tileSize >= 76 ? 15 : 13,
      chipFont: chipFont,
      chipPadX: chipPadX,
      chipPadY: chipPadY,
      titleFont: titleFont,
      widthVp: Math.round(widthVp),
      heightVp: Math.round(heightVp),
      densityPx: Math.round(density * 100) / 100,
      density: densityClass
    };
    return tokens;
  }

  /**
   * 分类 chip 的行数：按每个类目的真实字数估宽后贪心排布。
   * 只做估算，不参与渲染；算多了只会让图标略小，绝不会让内容溢出。
   */
  static chipRowCount(names: string[], font: number, padX: number, availW: number): number {
    if (!names || names.length === 0) return 0;
    let rows: number = 1;
    let x: number = 0;
    for (const name of names) {
      const w: number = (name ? name.length : 2) * font + padX * 2 + 8;
      if (x > 0 && x + w > availW) {
        rows += 1;
        x = w;
      } else {
        x += w;
      }
    }
    return rows;
  }

  /** 无实测尺寸时的基准布局（Node 测试 / 失败反馈推送的兜底）。 */
  static fallback(categoryNames: string[], frameCount: number): CardLayoutTokens {
    const size: CardSize = { widthPx: 0, heightPx: 0 };
    const input: CardLayoutInput = {
      size: size, density: 0, categoryNames: categoryNames, frameCount: frameCount
    };
    return CardLayout.compute(input);
  }
}

export default CardLayout;
