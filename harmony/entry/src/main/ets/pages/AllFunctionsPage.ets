import router from '@ohos.router';
import type common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { RefreshOrchestrator } from '../form/RefreshOrchestrator';
import { SearchFilter } from '../data/SearchFilter';
import { LaunchDispatcher } from '../launch/LaunchDispatcher';
import { createVerticalStarter } from '../launch/VerticalStarter';
import { createLinkOpener } from '../launch/LinkOpener';
import { UsageStore } from '../data/UsageStore';
import { LetterSections } from './LetterSections';
import type { LetterSection } from './LetterSections';
import { BrandMark } from '../form/BrandMark';
import { BrandLogo } from '../form/BrandLogo';
import { PagePalette } from '../form/PagePalette';
import { PageMetricsCalc } from '../form/PageMetrics';
import type { PageMetrics } from '../form/PageMetrics';
import type { AtomicFunction } from '../model/AtomicFunction';

/**
 * 全部功能 / 搜索页 —— 复刻用户提供的 iOS「App 资源库」搜索态（2026-11-09）。
 *
 * 参考图语汇：
 *  - 顶部胶囊搜索框 + 右侧「取消」；
 *  - 结果按拼音首字母分段，每段左侧一个大写字母标题；
 *  - 行 = App 图标 + 文字 + 细分隔线（不再用文件夹框网格）；
 *  - 右侧常驻 A–Z# 索引条，点击跳到对应字母段；
 *  - 背景是中性灰蓝柔光底 + 白玻璃面板，白字压在上面有对比度。
 *
 * 尺寸（搜索框高度 / 字号 / 行图标 / 留白）全部由 PageMetricsCalc 按容器
 * 实际宽度推导，不写死 —— 手机、平板、分屏共用一份代码。
 *
 * 性能：全部条目只在 aboutToAppear 读一次并缓存（旧实现每次按键都
 * effectiveRepository + listAll，打一个字就跨 bundle 探测一轮）；输入时
 * 只对缓存做纯内存过滤 + 拼音分组。
 */
@Entry
@Component
struct AllFunctionsPage {
  @State query: string = '';
  @State sections: LetterSection[] = [];
  @State total: number = 0;
  @State message: string = '';
  @State selectedIndex: number = 0;
  /** 按容器宽度推导出的内页尺寸；首帧用手机基准，onAreaChange 后更新。 */
  @State metrics: PageMetrics = PageMetricsCalc.baseline();
  private allItems: AtomicFunction[] = [];
  private letters: string[] = LetterSections.indexLetters();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadAll();
  }

  private async loadAll(): Promise<void> {
    const repo = RefreshOrchestrator.effectiveRepository(getContext(this));
    // 页面浏览不做「最近添加」探测：只有卡片侧需要 first-seen 表。
    this.allItems = await repo.listAll();
    this.applyFilter();
  }

  /** 纯内存过滤 + 按 A–Z# 分组；键盘输入每次只跑这一小段。 */
  private applyFilter(): void {
    const matched = SearchFilter.filter(this.allItems, this.query);
    this.sections = LetterSections.fromItems(matched);
    this.total = matched.length;
    this.selectedIndex = 0;
  }

  private buildUsage(): UsageStore {
    try {
      const pref = preferences.getPreferencesSync(getContext(this), { name: 'atomic_function_usage' });
      return UsageStore.withPreferencesSync(pref);
    } catch (_err) {
      return new UsageStore();
    }
  }

  private async onPick(fn: AtomicFunction): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const starter = async (want: Object) => {
      try {
        await ctx.startAbility(want);
        return true;
      } catch (_err) {
        return false;
      }
    };
    const verticalStarter = createVerticalStarter(ctx);
    const linkOpener = createLinkOpener(ctx);
    const r = await LaunchDispatcher.launch(fn, starter, this.buildUsage(), verticalStarter, linkOpener);
    this.message = r.ok ? '' : LaunchDispatcher.onFailure(fn, r);
  }

  /** iOS 语义：有输入时「取消」先清空搜索；无输入时返回上一页。 */
  private cancel(): void {
    if (this.query !== '') {
      this.query = '';
      this.applyFilter();
      return;
    }
    router.back();
  }

  private jumpTo(index: number): void {
    this.selectedIndex = index;
    const letter: string = this.letters[index];
    const sectionIndex: number = LetterSections.indexOfLetter(this.sections, letter);
    if (sectionIndex >= 0) {
      this.scroller.scrollToIndex(sectionIndex);
    }
  }

  /** 段标题：参考图的大写字母。尺寸按容器宽度推导。 */
  @Builder
  sectionHeader(letter: string) {
    Text(letter)
      .fontSize(this.metrics.titleFont * 0.76)
      .fontWeight(FontWeight.Bold)
      .fontColor(PagePalette.TEXT)
      .textShadow({ radius: 5, color: PagePalette.SHADOW, offsetX: 0, offsetY: 1 })
      .width('100%')
      .padding({ left: this.metrics.pagePad, right: this.metrics.indexWidth + 10, top: 10, bottom: 4 })
  }

  /** 行内 App 图标（真实 logo 优先，回退品牌色 + 字形）。 */
  @Builder
  rowIcon(fn: AtomicFunction) {
    Stack() {
      if (BrandMark.forApp(fn.appName, fn.label).hasLogo) {
        Image(BrandLogo.image(BrandMark.forApp(fn.appName, fn.label).key))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .borderRadius(this.metrics.rowIconSize * 0.24)
      } else {
        Column()
          .width('100%')
          .height('100%')
          .borderRadius(this.metrics.rowIconSize * 0.24)
          .backgroundColor(BrandMark.forApp(fn.appName, fn.label).bg)
        Column()
          .width('100%')
          .height('42%')
          .borderRadius({ topLeft: this.metrics.rowIconSize * 0.24, topRight: this.metrics.rowIconSize * 0.24 })
          .linearGradient({ angle: 90, colors: [['#33FFFFFF', 0], ['#00FFFFFF', 1]] })
        Text(BrandMark.forApp(fn.appName, fn.label).glyph)
          .fontSize(this.metrics.rowIconSize * 0.41)
          .fontWeight(FontWeight.Bold)
          .fontColor(BrandMark.forApp(fn.appName, fn.label).fg)
          .textShadow({ radius: 3, color: '#40000000', offsetX: 0, offsetY: 1 })
      }
    }
    .width(this.metrics.rowIconSize)
    .height(this.metrics.rowIconSize)
    .borderRadius(this.metrics.rowIconSize * 0.24)
    .border({ width: 0.6, color: PagePalette.TILE_BORDER })
    .clip(true)
  }

  /** 一行功能：图标 + 功能名 + App 名 + 细分隔线。 */
  @Builder
  functionRow(fn: AtomicFunction) {
    Column() {
      Row() {
        this.rowIcon(fn)
        Column() {
          Text(fn.label)
            .fontSize(this.metrics.rowFont)
            .fontWeight(FontWeight.Medium)
            .fontColor(PagePalette.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(fn.hint ? fn.appName + ' · ' + fn.hint : fn.appName)
            .fontSize(this.metrics.rowSubFont)
            .fontColor(PagePalette.TEXT_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 13 })
        Text('›')
          .fontSize(this.metrics.rowFont * 1.12)
          .fontColor(PagePalette.TEXT_DIM)
          .margin({ left: 6 })
      }
      .width('100%')
      .padding({
        left: this.metrics.pagePad, right: this.metrics.indexWidth + 10,
        top: 8, bottom: 8
      })

      // 分隔线左端对齐到文字起点（图标宽 + 间距），右端对齐到内容右边界。
      Divider()
        .color(PagePalette.DIVIDER)
        .strokeWidth(0.5)
        .margin({
          left: this.metrics.pagePad + this.metrics.rowIconSize + 13,
          right: this.metrics.indexWidth + 10
        })
    }
    .width('100%')
    .onClick(() => { this.onPick(fn); })
  }

  build() {
    Column() {
      // ── 顶部胶囊搜索框 + 取消（参考图布局） ──────────────────────
      // 用户真机反馈（2026-11-11）：
      //  1. 胶囊比里面的字高太多 → 高度与字号按容器宽度一起推导，比例恒定；
      //  2. 前面的「⌕」在输入态会显示成一个怪异的左括号 → 换成系统符号
      //     sys.symbol.magnifyingglass（真实放大镜图标），后面接原生竖线光标。
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(this.metrics.searchIconSize)
            .fontColor([PagePalette.TEXT_SUB])
            .margin({ right: this.metrics.searchPadX * 0.5 })
          TextInput({ placeholder: '搜索功能 / App / 分类', text: this.query })
            .onChange((v: string) => {
              this.query = v;
              this.applyFilter();
            })
            .fontSize(this.metrics.searchFont)
            .fontColor(PagePalette.TEXT)
            .placeholderColor(PagePalette.TEXT_DIM)
            .placeholderFont({ size: this.metrics.searchFont })
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            // 不用固定 height：让输入框在胶囊里垂直居中，换设备也不会错位。
            .padding(0)
            .borderRadius(0)
        }
        .layoutWeight(1)
        .height(this.metrics.searchHeight)
        .padding({ left: this.metrics.searchPadX, right: this.metrics.searchPadX * 0.9 })
        .backgroundColor(PagePalette.FRAME_BG)
        .border({ width: 1, color: PagePalette.FRAME_BORDER })
        .borderRadius(this.metrics.searchRadius)

        Text('取消')
          .fontSize(this.metrics.searchFont)
          .fontColor(PagePalette.TEXT)
          .textShadow({ radius: 4, color: PagePalette.SHADOW, offsetX: 0, offsetY: 1 })
          .margin({ left: this.metrics.searchPadX * 0.75 })
          .onClick(() => { this.cancel(); })
      }
      .width('100%')
      .padding({
        left: this.metrics.pagePad, right: this.metrics.pagePad, top: 14, bottom: 8
      })

      // ── 字母分段列表 + 右侧 A–Z# 索引 ────────────────────────────
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.sections.length === 0) {
          Column() {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(this.metrics.searchHeight * 0.85)
              .fontColor([PagePalette.TEXT_SUB])
            Text(this.query ? '未找到相关功能' : '暂无可用功能')
              .fontSize(this.metrics.rowFont)
              .fontColor(PagePalette.TEXT_SUB)
              .margin({ top: 10 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List({ scroller: this.scroller }) {
            // 真机缺陷（2026-11-11）：外层 ForEach 只按字母做 key，ListItemGroup
            // 会按同一个 key 复用旧的子项 —— 搜索「wps」时只剩 1 条，D 段却还
            // 挂着上一次的条目。key 必须包含该段的条目 id 列表与数量，内容一变
            // 就整段重建。这是 D1（FlatSections 带 query key）同一类问题的残留。
            ForEach(this.sections, (section: LetterSection) => {
              ListItemGroup({ header: this.sectionHeader(section.letter) }) {
                ForEach(section.items, (fn: AtomicFunction) => {
                  ListItem() {
                    this.functionRow(fn)
                  }
                }, (fn: AtomicFunction) => fn.id)
              }
            }, (section: LetterSection) => LetterSections.sectionKey(section))
          }
          .width('100%')
          .height('100%')
          .sticky(StickyStyle.Header)
          .scrollBar(BarState.Off)

          AlphabetIndexer({ arrayValue: this.letters, selected: this.selectedIndex })
            .color(PagePalette.TEXT_SUB)
            .selectedColor(PagePalette.TEXT)
            .popupColor(PagePalette.TEXT)
            .selectedBackgroundColor(PagePalette.FRAME_BG)
            .itemSize(Math.round(this.metrics.rowSubFont * 1.5))
            .width(this.metrics.indexWidth)
            .height('100%')
            .onSelect((index: number) => { this.jumpTo(index); })
        }
      }
      .width('100%')
      .layoutWeight(1)

      if (this.message) {
        Row() {
          Text('●').fontSize(9).fontColor(PagePalette.RED).margin({ right: 6 })
          Text(this.message).fontSize(this.metrics.rowSubFont).fontColor(PagePalette.TEXT)
        }
        .padding(12)
        .backgroundColor(PagePalette.FRAME_BG)
        .border({ width: 1, color: PagePalette.FRAME_BORDER })
        .borderRadius(14)
        .margin({ left: this.metrics.pagePad, right: this.metrics.pagePad, bottom: 14 })
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 150,
      colors: [[PagePalette.BG[0], 0], [PagePalette.BG[1], 0.45], [PagePalette.BG[2], 1]]
    })
    // 不写死任何尺寸：拿到容器真实宽度后重算整套 token（平板 / 分屏 / 折叠屏）。
    .onAreaChange((_old: Area, now: Area) => {
      const w: number = Number(now.width);
      if (w > 0 && Math.abs(w - this.metrics.widthVp) >= 2) {
        this.metrics = PageMetricsCalc.compute(w);
      }
    })
  }
}
