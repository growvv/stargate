import type { UsageSnapshot } from '../data/UsageStore';
import type { AtomicFunction } from '../model/AtomicFunction';
import { CapabilityRepository } from '../data/CapabilityRepository';
import { WidgetCardData } from './WidgetCardData';
import { ThemeTokens } from './ThemeTokens';
import type { ThemeValues } from './ThemeTokens';
import { CardFeedback } from './CardFeedback';
import { LIGHT, DARK } from './ThemeColors';
import { CardPalette } from './CardPalette';
import { BrandMark } from './BrandMark';
import type { AppMark } from './BrandMark';
import { GlassStyle, ACTIVE_VARIANT } from './GlassStyle';
import type { GlassTokens } from './GlassStyle';
import { CardLayout } from './CardLayout';
import type { CardLayoutTokens, CardSize } from './CardLayout';
import { RecentAdditions } from '../recommend/RecentAdditions';

/**
 * 卡片绑定数据的唯一组装点（C1 / I2 / I7 修复）。
 *
 * FormAbility（卡片提供方）与 EntryAbility（UIAbility 侧直达失败反馈）都用本类
 * 把「真实能力库 + 用量 + 主题 + 失败提示」组装成同一份 formBindingData 字段，
 * 避免两侧各自 new 空库（C1），也保证失败能推回卡片显示（I2）。
 *
 * D2 修复（真机 2026-11-07）：失败反馈是瞬态的。compose 用 `now` 判定
 * failureAt 是否过期，过期则把 failure 置空 —— 不再让一次失败常驻到下一次
 * 定时刷新 / force-stop 之后。failureAt 同时下发给卡片，供卡片侧按本地时钟判定。
 *
 * 精准复刻（2026-11-08）：每个建议项附带 BrandMark 的「应用原生标识」
 * （品牌色 + 品牌字形；未命中回退文字/颜色），并把 ACTIVE_VARIANT 的整套
 * 浅色磨砂玻璃 / 嵌套框 token 推给卡片，供三版比例迭代截图对比。
 *
 * 纯逻辑：只依赖 WidgetCardData / ThemeTokens / CapabilityRepository 等纯模块，
 * 不触碰 SDK，因此可被 Node 单测直接驱动，也能编译进卡片 widgets.abc。
 */

/** 卡片建议项（键与 WidgetCard 的 @LocalStorageProp('suggestions') 对齐）。
 *  视觉改版：附带稳定的图标 tile 渐变色与字形；精准复刻再附带应用原生标识。 */
export interface CardSuggestionItem {
  id: string;
  label: string;
  appName: string;
  category: string;
  tileStart: string;
  tileEnd: string;
  glyph: string;
  /** 品牌标识字段：命中品牌表时为原生品牌色/字形，否则为文字/颜色回退。 */
  markBg: string;
  markFg: string;
  markGlyph: string;
  markNative: boolean;
  markBrand: string;
  /** 真实 App logo 资源键（'' = 无 logo，卡片回退品牌色 + 符号）。 */
  logoKey: string;
}

/** 卡片分类 chip（键与 @LocalStorageProp('categories') 对齐）。 */
export interface CardCategoryItem {
  name: string;
  count: number;
}

/** 外层玻璃「文件夹框」：内含 ≤4 个功能图标框，框下带分类标签（嵌套框结构）。 */
export interface CardFolderFrame {
  /** ForEach 稳定 key。 */
  key: string;
  /** 框下方的标签（推荐 / 最近添加）。 */
  label: string;
  /** 该外层框内的功能（≤4，2×2）。 */
  items: CardSuggestionItem[];
  /** 空框提示（如「暂无最近添加」）；非空框为 ''。 */
  emptyHint: string;
}

/** formBindingData 的完整字段形状（arkts-no-untyped-obj-literals：须显式 interface）。 */
export interface CardBindingData {
  suggestions: CardSuggestionItem[];
  /** 精准复刻：嵌套文件夹框结构（外层框 → 内层 2×2 功能框）。 */
  frames: CardFolderFrame[];
  categories: CardCategoryItem[];
  contextHint: string;
  isEmpty: boolean;
  formId: string;
  failure: string;
  /** 失败提示产生时刻（ms）。0 = 旧版绑定/无失败；卡片据此按本地时钟判定 TTL。 */
  failureAt: number;
  cardBg: string;
  /** 半透明面板底色（用户拍板：不要彩色渐变，只要半透明玻璃面板）。 */
  panelBg: string;
  textPrimary: string;
  textSecondary: string;
  dividerColor: string;
  border: string;
  radiusCard: number;
  radiusChip: number;
  radiusIcon: number;
  blurRadius: number;
  gradientDark: boolean;
  /** 精准复刻：浅色磨砂玻璃 / 嵌套框 token（键名与 WidgetCard 的
   *  @LocalStorageProp 一一对应，否则卡片会退回默认值、拿不到三版比例）。 */
  frameBg: string;
  frameBorder: string;
  tileBg: string;
  tileBorder: string;
  wallpaper: string[];
  radiusFrame: number;
  radiusTile: number;
  tileSize: number;
  tileGap: number;
  frameGap: number;
  framesPerScreen: number;
  frameAspect: number;
  activeVariant: number;
  /** 尺寸自适应 token（CardLayout 按卡片实测宽高推导）。 */
  tileLabelFont: number;
  tileLabelLine: number;
  tileLabelLines: number;
  frameLabelFont: number;
  chipFont: number;
  chipPadX: number;
  chipPadY: number;
  titleFont: number;
  cardWidthVp: number;
  cardHeightVp: number;
}

export class CardBinding {
  /**
   * 同一格里的同名功能消歧（真机 2026-11-11 发现）。
   *
   * 能力库里「存储空间」有 10 条、「打开文件」5 条、「登录」5 条 —— 每个 App
   * 都有自己的清理缓存入口。卡片一格只显示功能名，真机上「推荐」四个格子里
   * 出现了两个「存储空间」（QQ音乐 / 微博），用户分不出点哪个。
   *
   * 规则：**只在同一个框内**出现重名时，重名的这几格改用 App 名；App 名也撞
   * 才退回「App 名 · 功能名」。不重名的一律保持原样 —— 功能名比 App 名更具体，
   * 不能因为别的框里有重名就把所有格子都改成 App 名。
   *
   * 判定「App 名也撞」看的是**改名后的标签在框内是否唯一**，不是「这个 App 在框
   * 里出现了几次」。真机 2026-11-11：「推荐」里微博占 3 格（存储空间 / 打开微博 /
   * 付款），按出现次数算会把其中一条改成「微博 · 存储空间」，10 号字在手机卡片
   * 上换行成「存储空 / 间」，反而更乱；而「微博」和同框的「打开微博」「付款」并不
   * 冲突，只用 App 名就足够区分。
   */
  static disambiguate(items: CardSuggestionItem[]): void {
    if (!items || items.length < 2) return;
    const counts: Map<string, number> = new Map<string, number>();
    for (const it of items) {
      const n: number | undefined = counts.get(it.label);
      counts.set(it.label, (n === undefined ? 1 : n + 1));
    }
    const renamed: CardSuggestionItem[] = [];
    for (const it of items) {
      const n: number | undefined = counts.get(it.label);
      if (n !== undefined && n > 1) renamed.push(it);
    }
    if (renamed.length === 0) return;
    // 先假设重名条目都只用 App 名，数一遍改名后各标签在框内出现几次。
    const proposed: Map<string, number> = new Map<string, number>();
    const bump = (label: string): void => {
      const n: number | undefined = proposed.get(label);
      proposed.set(label, n === undefined ? 1 : n + 1);
    };
    for (const it of items) if (renamed.indexOf(it) < 0) bump(it.label);
    for (const it of renamed) bump(it.appName);
    // App 名仍然撞（同一 App 的多条同名功能，或撞上别的功能名）才带功能名。
    for (const it of renamed) {
      const n: number | undefined = proposed.get(it.appName);
      it.label = (n !== undefined && n > 1) ? it.appName + ' · ' + it.label : it.appName;
    }
  }

  /** 把能力条目映射为卡片建议项（推荐与最近添加共用同一份视觉映射）。 */
  private static toSuggestion(f: AtomicFunction): CardSuggestionItem {
    const tile = CardPalette.tileFor(f.id);
    const mark: AppMark = BrandMark.forApp(f.appName, f.label);
    return {
      id: f.id,
      label: f.label,
      // 卡片空间有限：把「需登录 / 需同意 / 选择打开」并进 App 名一行；
      // 功能名单独显示在图标下方（用户要求每个图标都有文字说明）。
      appName: f.hint ? f.appName + ' · ' + f.hint : f.appName,
      category: f.category,
      tileStart: tile.start,
      tileEnd: tile.end,
      glyph: CardPalette.glyphOf(f.label),
      markBg: mark.bg,
      markFg: mark.fg,
      markGlyph: mark.glyph,
      markNative: mark.native,
      markBrand: mark.brand,
      logoKey: mark.hasLogo ? mark.key : ''
    };
  }

  /**
   * 组装一份完整绑定数据。
   * repo 必须是已接入 D5 的真实能力库（fromContextSync），不能是 fromItems([])。
   * failure 非空时卡片显示「暂无可用直达入口」提示（I2）；dark/blurAvailable 决定主题（I7）。
   * @param failureAt 失败产生时刻；缺省时若 failure 非空则取 now（新失败），否则 0。
   * @param cardSize 卡片实测宽高（**像素**）。卡片提供方从 onAddForm 的 want 参数读到；
   *                 缺省时用设计基准，保证 Node 测试与失败推送也能拿到合理尺寸。
   * @param density  屏幕像素密度（px → vp）。系统给的是 px，ArkUI 用 vp，必须换算。
   */
  static compose(repo: CapabilityRepository, usage: UsageSnapshot, now: number,
    formId: string, failure: string, dark: boolean, blurAvailable: boolean,
    failureAt?: number, categoryOrder?: string[],
    bundleFirstSeen?: Record<string, number>,
    cardSize?: CardSize, density?: number): CardBindingData {
    const view = WidgetCardData.buildSync(repo, usage, now, categoryOrder);
    const theme: ThemeValues = ThemeTokens.build(blurAvailable, dark);
    const at = failureAt ?? (failure ? now : 0);
    // D2：过期的失败文案不再进入绑定（瞬态反馈，非常驻状态）。
    const shown = CardFeedback.visibleAt(failure, at, now) ? failure : '';
    // 精准复刻：当前生效的浅色玻璃 / 嵌套框比例 token。
    const glass: GlassTokens = GlassStyle.active();

    const suggestions: CardSuggestionItem[] = [];
    for (const f of view.suggestions) suggestions.push(CardBinding.toSuggestion(f));
    const categories: CardCategoryItem[] = [];
    for (const c of view.categories) {
      categories.push({ name: c.name, count: c.count });
    }
    // 用户拍板（2026-11-09）：第一排只保留两个框 ——「推荐」与「最近添加」。
    // 推荐取排序前 4（2×2）；最近添加取「我们能探测到存在、首次出现时间最新」
    // 的 App 能力（≤4，每个 App 只占一格，跳过系统选应用入口）。默认按能力库
    // 尾部填充；用户后来安装的 App 被探测到后会替换旧条目（见 RecentAdditions）。
    const frames: CardFolderFrame[] = [];
    const recommended: CardSuggestionItem[] = suggestions.slice(0, 4);
    const recentAdded: CardSuggestionItem[] = [];
    for (const f of RecentAdditions.select(repo.itemsSnapshot(), bundleFirstSeen, 4)) {
      recentAdded.push(CardBinding.toSuggestion(f));
    }
    // 同框重名消歧（见 disambiguate 注释）：真机上「推荐」出现过两个「存储空间」。
    CardBinding.disambiguate(recommended);
    CardBinding.disambiguate(recentAdded);
    const pushFrame = (label: string, items: CardSuggestionItem[], emptyHint: string): void => {
      if (items.length === 0 && emptyHint === '') return;
      // key 必须随内容变化（含 label / 各条目 id）：ForEach 按 key 复用子树，
      // 纯位置 key 会让 updateForm 推来的新绑定继续复用首次添加时的旧标签。
      let ids: string = '';
      for (const it of items) ids += it.id + '|';
      frames.push({
        key: 'frame:' + label + ':' + items.length + ':' + ids,
        label: label,
        items: items,
        emptyHint: items.length > 0 ? '' : emptyHint
      });
    };
    if (suggestions.length > 0) {
      pushFrame('推荐', recommended, '');
      pushFrame('最近添加', recentAdded, '暂无最近添加');
    }
    // 尺寸自适应：按卡片实测宽高 + 实际 chips 数量推导 token。
    const size: CardSize = cardSize ?? { widthPx: 0, heightPx: 0 };
    const chipNames: string[] = [];
    for (const c of categories) chipNames.push(c.name);
    const layout: CardLayoutTokens = CardLayout.compute({
      size: size, density: density ?? 0, categoryNames: chipNames, frameCount: frames.length
    });
    const binding: CardBindingData = {
      suggestions: suggestions,
      frames: frames,
      categories: categories,
      contextHint: view.contextHint,
      isEmpty: view.isEmpty,
      formId: formId,
      failure: shown,
      failureAt: shown ? at : 0,
      cardBg: theme.cardBg,
      panelBg: '#4D000000',
      textPrimary: theme.textPrimary,
      textSecondary: theme.textSecondary,
      dividerColor: dark ? DARK.divider : LIGHT.divider,
      border: theme.border,
      radiusCard: theme.radiusCard,
      radiusChip: theme.radiusChip,
      radiusIcon: theme.radiusIcon,
      blurRadius: theme.blur === '' ? 0 : 13,
      gradientDark: dark,
      frameBg: glass.frameBg,
      frameBorder: glass.frameBorder,
      tileBg: glass.tileBg,
      tileBorder: glass.tileBorder,
      wallpaper: glass.wallpaper,
      radiusFrame: glass.radiusFrame,
      radiusTile: glass.radiusTile,
      // 图标尺寸/行距/框间距一律取实测布局结果，不能再回退到 GlassStyle 的
      // 固定 60 —— 那正是真机重叠的根因（720 设计宽下的常量直接用在 326vp 卡片）。
      tileSize: layout.tileSize,
      tileGap: layout.tileGap,
      frameGap: layout.frameGap,
      framesPerScreen: glass.framesPerScreen,
      frameAspect: glass.frameAspect,
      activeVariant: ACTIVE_VARIANT,
      tileLabelFont: layout.tileLabelFont,
      tileLabelLine: layout.tileLabelLine,
      tileLabelLines: layout.tileLabelLines,
      frameLabelFont: layout.frameLabelFont,
      chipFont: layout.chipFont,
      chipPadX: layout.chipPadX,
      chipPadY: layout.chipPadY,
      titleFont: layout.titleFont,
      cardWidthVp: layout.widthVp,
      cardHeightVp: layout.heightVp
    };
    return binding;
  }
}

export default CardBinding;
