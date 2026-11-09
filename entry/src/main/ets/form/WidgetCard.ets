import { PageRouter } from '../pages/PageRouter';
import { CardFeedback } from './CardFeedback';
import { BrandLogo } from './BrandLogo';

/**
 * 4×4 服务卡片 —— 精准复刻 iOS App Library / 展开文件夹（2026-11-08）。
 *
 * 参考图语汇（与上一版深色磨砂的根本区别）：
 *  - 浅色壁纸：蓝→青→蓝绿柔光渐变，不是深藏青；
 *  - 外层「文件夹框」：15% 白半透明磨砂 + 1px 亮白细边 + 顶部内高光 +
 *    大圆角 + 柔和外阴影，框下带分类 / 品牌标签；
 *  - 嵌套框结构：外层框内嵌 2×2 的「功能图标框」，每个功能用独立圆角框划分；
 *  - 应用原生标识：BrandMark 的品牌色 + 品牌字形（支付宝蓝「支」/ 微信绿「微」…），
 *    未命中则回退「标签首字 + 稳定颜色」；
 *  - 绝不用普通列表。
 *
 * 卡片渲染进程独立：只用 ArkUI 子集（Column/Row/Stack/Flex/Text/Blank/Divider/
 * ForEach，均带 @form 支持），不引入 @State/@Link、自定义组件、Navigation、
 * Grid（无 @form）、Scroll（无 @form）、网络/文件系统、长按/拖拽。
 * 数据经 @LocalStorageProp 由 FormAbility 的 formBindingData 推送。
 *
 * 三版比例迭代：GlassStyle.ACTIVE_VARIANT 决定外层框比例 / 内框尺寸 / 间距，
 * 整套 token（frameBg / tileSize / radius…）由 CardBinding 推入 LocalStorage。
 *
 * 事件链路：功能点击 / 分类 chip / 更多 / 配置 → postCardAction 'router' → EntryAbility。
 * I2/D2：失败提示按 failureAt + 本地时钟判定 TTL，提供「×」主动清除。
 * D3：所有 8 位 hex 均为 AARRGGBB（alpha 在首位）。
 */

interface SuggestionItem {
  id: string;
  label: string;
  appName: string;
  category: string;
  tileStart: string;
  tileEnd: string;
  glyph: string;
  markBg: string;
  markFg: string;
  markGlyph: string;
  markNative: boolean;
  markBrand: string;
  /** 真实 App logo 资源键（'' = 无 logo，回退品牌色 + 符号）。 */
  logoKey: string;
}

/** 外层玻璃文件夹框（嵌套框结构）。 */
interface FolderFrame {
  key: string;
  label: string;
  items: SuggestionItem[];
  /** 空框提示（「暂无最近添加」）；非空框为 ''。 */
  emptyHint: string;
}

interface CategoryChipItem {
  name: string;
  count: number;
}

/** postCardAction('message') 的 params：请求卡片提供方清除失败提示。 */
interface ClearFailureParams {
  action: string;
}

let storage = new LocalStorage();
storage.setOrCreate('suggestions', []);
storage.setOrCreate('frames', []);
storage.setOrCreate('categories', []);
storage.setOrCreate('contextHint', '');
storage.setOrCreate('isEmpty', false);
storage.setOrCreate('formId', '');
storage.setOrCreate('failure', '');
storage.setOrCreate('failureAt', 0);
storage.setOrCreate('cardBg', '#26FFFFFF');
// 用户拍板：卡片背景改为半透明中性面板，不再用蓝→青→绿彩色渐变。
storage.setOrCreate('panelBg', '#4D000000');
storage.setOrCreate('textPrimary', '#FFFFFFFF');
storage.setOrCreate('textSecondary', '#E6FFFFFF');
storage.setOrCreate('dividerColor', '#66FFFFFF');
storage.setOrCreate('radiusCard', 26);
storage.setOrCreate('radiusChip', 14);
storage.setOrCreate('radiusIcon', 16);
storage.setOrCreate('blurRadius', 22);
storage.setOrCreate('gradientDark', false);
// 精准复刻：浅色磨砂玻璃 / 嵌套框 token（与内页统一，由 CardBinding 推送）。
storage.setOrCreate('frameBg', '#26FFFFFF');
storage.setOrCreate('frameBorder', '#8CFFFFFF');
storage.setOrCreate('tileBg', '#33FFFFFF');
storage.setOrCreate('tileBorder', '#66FFFFFF');
storage.setOrCreate('wallpaper', ['#4A8FD4', '#54B0C4', '#79C7B0']);
storage.setOrCreate('radiusFrame', 26);
storage.setOrCreate('radiusTile', 16);
storage.setOrCreate('tileSize', 108);
storage.setOrCreate('tileGap', 12);
storage.setOrCreate('frameGap', 18);
storage.setOrCreate('frameAspect', 1.0);
storage.setOrCreate('activeVariant', 2);

@Entry(storage)
@Component
struct WidgetCard {
  @LocalStorageProp('suggestions') suggestions: SuggestionItem[] = [];
  @LocalStorageProp('frames') frames: FolderFrame[] = [];
  @LocalStorageProp('categories') categories: CategoryChipItem[] = [];
  @LocalStorageProp('contextHint') contextHint: string = '';
  @LocalStorageProp('isEmpty') isEmpty: boolean = false;
  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('failure') failure: string = '';
  @LocalStorageProp('failureAt') failureAt: number = 0;
  @LocalStorageProp('cardBg') cardBg: string = '#26FFFFFF';
  @LocalStorageProp('panelBg') panelBg: string = '#4D000000';
  @LocalStorageProp('textPrimary') textPrimary: string = '#FFFFFFFF';
  @LocalStorageProp('textSecondary') textSecondary: string = '#E6FFFFFF';
  @LocalStorageProp('dividerColor') dividerColor: string = '#66FFFFFF';
  @LocalStorageProp('radiusCard') radiusCard: number = 26;
  @LocalStorageProp('radiusChip') radiusChip: number = 14;
  @LocalStorageProp('radiusIcon') radiusIcon: number = 16;
  @LocalStorageProp('blurRadius') blurRadius: number = 22;
  @LocalStorageProp('gradientDark') gradientDark: boolean = false;
  @LocalStorageProp('frameBg') frameBg: string = '#26FFFFFF';
  @LocalStorageProp('frameBorder') frameBorder: string = '#8CFFFFFF';
  @LocalStorageProp('tileBg') tileBg: string = '#33FFFFFF';
  @LocalStorageProp('tileBorder') tileBorder: string = '#66FFFFFF';
  @LocalStorageProp('wallpaper') wallpaper: string[] = ['#4A8FD4', '#54B0C4', '#79C7B0'];
  @LocalStorageProp('radiusFrame') radiusFrame: number = 26;
  @LocalStorageProp('radiusTile') radiusTile: number = 16;
  @LocalStorageProp('tileSize') tileSize: number = 108;
  @LocalStorageProp('tileGap') tileGap: number = 12;
  @LocalStorageProp('frameGap') frameGap: number = 18;
  @LocalStorageProp('frameAspect') frameAspect: number = 1.0;
  @LocalStorageProp('activeVariant') activeVariant: number = 2;

  /** D2：失败提示只在 TTL 内显示（复用纯逻辑，与 FormAbility 一致）。 */
  private failureVisible(): boolean {
    return CardFeedback.visibleAt(this.failure, this.failureAt, Date.now());
  }

  private clearFailure(): void {
    const p: ClearFailureParams = { action: 'clearFailure' };
    postCardAction(this, { action: 'message', params: p });
  }

  /**
   * 单个功能图标 + 功能名文字（用户 2026-11-09 明确要求：推荐 / 最近添加里
   * 不能只放图标，每个图标必须有对应功能的文字说明）。
   * 图标在上、功能名在下（最多 2 行，超出省略），整块可点直达。
   */
  @Builder
  functionTile(item: SuggestionItem) {
    Column() {
      Stack() {
        if (item.logoKey !== '') {
          // 用户拍板：优先使用 App 官方 logo 本体，同一 App 的所有功能共用。
          Image(BrandLogo.image(item.logoKey))
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
            .borderRadius(this.radiusTile)
        } else {
          // 无官方图标的系统应用：品牌色底 + 中性符号（不再用中文字）。
          Column()
            .width('100%')
            .height('100%')
            .borderRadius(this.radiusTile)
            .backgroundColor(item.markBg)
          Column()
            .width('100%')
            .height('42%')
            .borderRadius({ topLeft: this.radiusTile, topRight: this.radiusTile })
            .linearGradient({
              angle: 90,
              colors: [['#33FFFFFF', 0], ['#00FFFFFF', 1]]
            })
          Text(item.markGlyph)
            .fontSize(this.tileSize > 100 ? 46 : (this.tileSize < 70 ? 26 : 36))
            .fontWeight(FontWeight.Bold)
            .fontColor(item.markFg)
            .textAlign(TextAlign.Center)
            .textShadow({ radius: 4, color: '#40000000', offsetX: 0, offsetY: 1 })
        }
      }
      .width(this.tileSize)
      .height(this.tileSize)
      .borderRadius(this.radiusTile)
      .border({ width: 0.6, color: this.tileBorder })
      .shadow({ radius: this.tileSize > 100 ? 10 : 7, color: '#40000000', offsetX: 0, offsetY: 3 })
      .clip(true)

      // 功能名（不是 App 名）：每个图标都有可见文字说明。
      Text(item.label)
        .fontSize(10.5)
        .lineHeight(12.5)
        .fontColor(this.textPrimary)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 3 })
        .textShadow({ radius: 3, color: '#80000000', offsetX: 0, offsetY: 1 })
    }
    .width('50%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .onClick(() => {
      postCardAction(this, PageRouter.routerAction(PageRouter.launchParams(item.id, this.formId)));
    })
  }

  /** 一个功能框里的一行（2 个图标 + 文字）。top 控制第二行的行距。 */
  @Builder
  tileRow(items: SuggestionItem[], top: number) {
    Row() {
      ForEach(items, (item: SuggestionItem) => {
        this.functionTile(item)
      }, (item: SuggestionItem) => item.id)
    }
    .justifyContent(FlexAlign.SpaceEvenly)
    .alignItems(VerticalAlign.Top)
    .width('100%')
    .margin({ top: top })
  }

  /**
   * 外层玻璃「文件夹框」：15% 白 + 亮白细边 + 2×2（图标 + 功能名）+ 框下标签。
   *
   * 2026-11-09 布局修复：去掉 `.aspectRatio(frameAspect)`。该比例把外框高度
   * 锁成固定值，而框内实际内容（两行图标 + 新增的文字标签）更高，布局权重
   * 分到的高度装不下，内容溢出画到下面的分类 chips 上（真机截图的重叠）。
   * 现在高度由内容自然撑开，外框、框下标签、chips 依次排布，不再重叠。
   */
  @Builder
  folderFrame(frame: FolderFrame) {
    Column() {
      // ── 外层框本体（嵌套框结构的外层） ──────────────────────────────
      Column() {
        if (frame.items.length === 0) {
          // 最近添加为空：诚实空态，不拿推荐条目冒充（B2′）。
          Column() {
            Text('◷').fontSize(30).fontColor(this.textSecondary)
            Text(frame.emptyHint)
              .fontSize(13)
              .fontColor(this.textSecondary)
              .textAlign(TextAlign.Center)
              .margin({ top: 8 })
          }
          .width('100%')
          .height(this.tileSize * 2 + 56)
          .justifyContent(FlexAlign.Center)
        } else {
          // 内层 2×2：每格 = 图标 + 功能名（第一行）
          this.tileRow(frame.items.slice(0, 2), 0)
          // 内层 2×2：第二行（行距收紧，把高度留给文字）
          if (frame.items.length > 2) {
            this.tileRow(frame.items.slice(2, 4), this.tileGap)
          }
        }
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 8, bottom: 10 })
      .backgroundColor(this.frameBg)
      .borderRadius(this.radiusFrame)
      .border({ width: 1, color: this.frameBorder })
      .shadow({ radius: 14, color: '#30000000', offsetX: 0, offsetY: 6 })

      // 框下方的标签（推荐 / 最近添加）—— 用户要求字号稍大
      Text(frame.label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textPrimary)
        .textAlign(TextAlign.Center)
        .textShadow({ radius: 4, color: '#80000000', offsetX: 0, offsetY: 1 })
        .margin({ top: 6 })
        .width('100%')
    }
    .width('46%')
    .margin({ bottom: this.frameGap })
  }

  build() {
    Stack() {
      // 浅色柔光壁纸（蓝→青→蓝绿），不是深色藏青
      Column() {
        // ── 顶栏：标题 + 胶囊「更多 ›」 ──────────────────────────────
        Row() {
          Column() {
            Text('StarGate')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textPrimary)
              .textShadow({ radius: 6, color: '#80000000', offsetX: 0, offsetY: 1 })
            Text('常用功能 · 点图标直达')
              .fontSize(11)
              .fontColor(this.textSecondary)
              .maxLines(1)
              .margin({ top: 3 })
          }.alignItems(HorizontalAlign.Start)
          Blank()
          Text('探索')
            .fontSize(13)
            .fontColor(this.textPrimary)
            .padding({ left: 11, right: 11, top: 7, bottom: 7 })
            .backgroundColor(this.frameBg)
            .border({ width: 0.6, color: this.frameBorder })
            .borderRadius(15)
            .margin({ right: 7 })
            .onClick(() => {
              postCardAction(this, PageRouter.routerAction(PageRouter.explorerParams()));
            })
          Text('更多 ›')
            .fontSize(13)
            .fontColor(this.textPrimary)
            .padding({ left: 13, right: 13, top: 7, bottom: 7 })
            .backgroundColor(this.frameBg)
            .border({ width: 0.6, color: this.frameBorder })
            .borderRadius(15)
            .onClick(() => {
              postCardAction(this, PageRouter.routerAction(PageRouter.allParams()));
            })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 12 })

        // ── 主体：外层玻璃文件夹框（2 列，嵌套 2×2 功能框） ──────────
        if (this.frames.length === 0) {
          // 诚实空态（A3）：空能力库不补假图标
          Column() {
            Text('▦').fontSize(40).fontColor(this.textSecondary)
            Text('添加你常用的功能').fontSize(15).fontColor(this.textSecondary)
              .margin({ top: 8 })
            Text('配置')
              .fontSize(13)
              .fontColor(this.textPrimary)
              .backgroundColor(this.frameBg)
              .border({ width: 0.6, color: this.frameBorder })
              .borderRadius(this.radiusChip)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .margin({ top: 12 })
              .onClick(() => {
                postCardAction(this, PageRouter.routerAction(PageRouter.configParams()));
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          // 两列文件夹框：用 Flex 换行，每框宽 46%（Form 安全，不用 Grid）
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceEvenly }) {
            ForEach(this.frames, (frame: FolderFrame) => {
              this.folderFrame(frame)
            }, (frame: FolderFrame) => frame.key)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 6 })
          .layoutWeight(1)
        }

        // ── 玻璃胶囊分类 chips（可换行，全部可见） ─────────────────────
        // 精准复刻参考图 1：文件夹框下直接是分类标签，再往下是分类入口，
        // 不再放「按分类浏览」小节标题（真机 V0 证实它与框下标签重叠）。
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.categories, (chip: CategoryChipItem) => {
            Text(chip.name)
              .fontSize(13.5)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.textPrimary)
              .backgroundColor(this.frameBg)
              .border({ width: 0.6, color: this.frameBorder })
              .borderRadius(this.radiusChip)
              .padding({ left: 12, right: 12, top: 5, bottom: 5 })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                postCardAction(this, PageRouter.routerAction(PageRouter.categoryParams(chip.name)));
              })
          }, (chip: CategoryChipItem) => chip.name)
        }
        .width('100%')
        .padding({ left: 20, right: 12 })

        Divider().color(this.dividerColor).strokeWidth(0.5)
          .margin({ left: 18, right: 18, top: 3, bottom: 3 })

        // ── 底部：情境提示 / 失败提示 ───────────────────────────────
        if (this.failureVisible()) {
          Row() {
            Text('●').fontSize(10).fontColor('#ff6b6b').margin({ right: 5 })
            Text(this.failure).fontSize(11.5).fontColor(this.textSecondary)
            Blank()
            Text('×')
              .fontSize(14)
              .fontColor(this.textSecondary)
              .margin({ right: 14 })
              .onClick(() => { this.clearFailure(); })
          }.padding({ left: 18, bottom: 10 })
        } else {
          Text(this.contextHint)
            .fontSize(11.5)
            .fontColor(this.textSecondary)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ bottom: 10 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .borderRadius(this.radiusCard)
      .border({ width: 1, color: this.frameBorder })
      .shadow({ radius: 18, color: '#30000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .height('100%')
    // 用户拍板：去掉彩色渐变壁纸，改成半透明中性面板（透过磨砂看到桌面）。
    .backgroundColor(this.panelBg)
    .borderRadius(this.radiusCard)
    .backdropBlur(this.blurRadius)
  }
}
