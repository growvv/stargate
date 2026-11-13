import router from '@ohos.router';
import type common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { RefreshOrchestrator } from '../form/RefreshOrchestrator';
import { SearchFilter } from '../data/SearchFilter';
import { LaunchDispatcher } from '../launch/LaunchDispatcher';
import { createVerticalStarter } from '../launch/VerticalStarter';
import { createLinkOpener } from '../launch/LinkOpener';
import { UsageStore } from '../data/UsageStore';
import { BrandMark } from '../form/BrandMark';
import { BrandLogo } from '../form/BrandLogo';
import { PagePalette } from '../form/PagePalette';
import { PageMetricsCalc } from '../form/PageMetrics';
import type { PageMetrics } from '../form/PageMetrics';
import type { AtomicFunction } from '../model/AtomicFunction';

/**
 * 分类功能页（点卡片分类 chip 打开）—— 精准复刻 iOS「展开文件夹」（2026-11-08）。
 *
 * 中性灰蓝柔光底 + 白玻璃面板 + 白色大标题 + 4 列 App 图标网格。
 * 外层玻璃「文件夹框」内嵌功能图标框（嵌套框结构），每个功能用独立圆角框
 * 划分，绝不用普通列表。
 *
 * 尺寸全部由 PageMetricsCalc 按容器实际宽度推导（图标边长 = 一行 4 个均分），
 * 不写死 —— 平板 / 分屏 / 折叠屏共用一份代码。
 *
 * 应用原生标识：BrandMark 品牌色 + 品牌字形；未命中回退文字/颜色。
 * 搜索在分类内过滤，query 参与 key（D1 无陈旧框残留）。
 */
@Entry
@Component
struct CategoryPage {
  @State category: string = '';
  @State query: string = '';
  @State items: AtomicFunction[] = [];
  @State message: string = '';
  /** 按容器宽度推导出的内页尺寸；首帧用手机基准，onAreaChange 后更新。 */
  @State metrics: PageMetrics = PageMetricsCalc.baseline();

  aboutToAppear(): void {
    const ls = LocalStorage.getShared();
    this.category = (ls?.get('category') as string) ?? '';
    this.reload();
  }

  private async reload(): Promise<void> {
    const repo = RefreshOrchestrator.effectiveRepository(getContext(this));
    const all = await repo.listByCategory(this.category);
    this.items = SearchFilter.filter(all, this.query);
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

  /** 单个功能图标框（品牌标识 + 标签），嵌套在外层文件夹框里。 */
  @Builder
  functionTile(fn: AtomicFunction) {
    Column() {
      Stack() {
        if (BrandMark.forApp(fn.appName, fn.label).hasLogo) {
          // 真实 App logo（同一 App 的所有功能共用）。
          Image(BrandLogo.image(BrandMark.forApp(fn.appName, fn.label).key))
            .width('100%').height('100%')
            .objectFit(ImageFit.Cover)
            .borderRadius(this.metrics.tileRadius)
        } else {
          Column()
            .width('100%').height('100%')
            .borderRadius(this.metrics.tileRadius)
            .backgroundColor(BrandMark.forApp(fn.appName, fn.label).bg)
          Column()
            .width('100%').height('42%')
            .borderRadius({ topLeft: this.metrics.tileRadius, topRight: this.metrics.tileRadius })
            .linearGradient({ angle: 90, colors: [['#33FFFFFF', 0], ['#00FFFFFF', 1]] })
          Text(BrandMark.forApp(fn.appName, fn.label).glyph)
            .fontSize(this.metrics.tileSize * 0.42).fontWeight(FontWeight.Bold)
            .fontColor(BrandMark.forApp(fn.appName, fn.label).fg)
            .textShadow({ radius: 3, color: '#40000000', offsetX: 0, offsetY: 1 })
        }
      }
      .width(this.metrics.tileSize)
      .height(this.metrics.tileSize)
      .borderRadius(this.metrics.tileRadius)
      .border({ width: 0.6, color: PagePalette.TILE_BORDER })
      .shadow({ radius: 8, color: '#30000000', offsetX: 0, offsetY: 3 })
      .clip(true)
      // 标签宽度按格子均分（含一格间距），不写死 —— 换设备不会挤成一条线。
      // 标签占满整格（宽度由外层 25% 决定），不写死 —— 换设备不会挤到邻格。
      Text(fn.label).fontSize(this.metrics.rowSubFont + 1).fontColor(PagePalette.TEXT).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .textShadow({ radius: 3, color: PagePalette.SHADOW, offsetX: 0, offsetY: 1 })
        .margin({ top: 6 })
        .width('100%')
      Text(fn.hint ? fn.appName + ' · ' + fn.hint : fn.appName)
        .fontSize(this.metrics.rowSubFont - 1).fontColor(PagePalette.TEXT_SUB).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center).width('100%')
    }
    // 每格固定 1/4 行宽：一行恒为 4 个，图标再大也不会把第 4 格挤出屏幕。
    .width('25%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.onPick(fn); })
  }

  /** 一行功能图标框（最多 4 个，参考图展开文件夹的 4 列网格）。 */
  @Builder
  tileRow(items: AtomicFunction[], top: number) {
    Row() {
      ForEach(items, (fn: AtomicFunction) => {
        this.functionTile(fn)
      }, (fn: AtomicFunction) => fn.id)
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .margin({ top: top })
  }

  build() {
    Column() {
      // ── 顶栏 ──────────────────────────────────────────────────────
      Row() {
        Text('‹ 返回').fontSize(this.metrics.rowFont).fontColor(PagePalette.TEXT)
          .textShadow({ radius: 4, color: PagePalette.SHADOW, offsetX: 0, offsetY: 1 })
          .onClick(() => { router.back(); })
        Blank()
      }.width('100%').padding({
        left: this.metrics.pagePad, right: this.metrics.pagePad, top: 18, bottom: 4
      })

      // ── 展开文件夹式大标题（参考图） ──────────────────────────────
      Text(this.category)
        .fontSize(this.metrics.titleFont).fontWeight(FontWeight.Bold).fontColor(PagePalette.TEXT)
        .textShadow({ radius: 8, color: PagePalette.SHADOW, offsetX: 0, offsetY: 2 })
        .textAlign(TextAlign.Start)
        .width('100%')
        .padding({ left: this.metrics.pagePad })
        .margin({ bottom: 12 })

      // ── 浅色磨砂胶囊搜索栏（与搜索页同一套推导尺寸） ──────────────
      Row() {
        Row() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(this.metrics.searchIconSize)
            .fontColor([PagePalette.TEXT_SUB])
            .margin({ right: this.metrics.searchPadX * 0.5 })
          TextInput({ placeholder: '搜索功能 / App' })
            .onChange((v: string) => { this.query = v; this.reload(); })
            .fontSize(this.metrics.searchFont)
            .fontColor(PagePalette.TEXT)
            .placeholderColor(PagePalette.TEXT_DIM)
            .placeholderFont({ size: this.metrics.searchFont })
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .padding(0)
            .borderRadius(0)
        }
        .width('100%')
        .height(this.metrics.searchHeight)
        .padding({ left: this.metrics.searchPadX, right: this.metrics.searchPadX })
        .backgroundColor(PagePalette.FRAME_BG)
        .border({ width: 1, color: PagePalette.FRAME_BORDER })
        .borderRadius(this.metrics.searchRadius)
      }
      .width('100%')
      .padding({ left: this.metrics.pagePad, right: this.metrics.pagePad, bottom: 14 })

      if (this.items.length === 0) {
        // 诚实空态
        Column() {
          Text('▦').fontSize(this.metrics.titleFont * 1.2).fontColor(PagePalette.TEXT_SUB)
          Text('该分类暂无可用功能').fontSize(this.metrics.rowFont).fontColor(PagePalette.TEXT_SUB).margin({ top: 10 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          // ── 外层玻璃文件夹框（嵌套框结构），内含功能图标框网格 ──
          Column() {
            Column()
              .width('100%').height(30)
              .borderRadius({ topLeft: PagePalette.FRAME_RADIUS, topRight: PagePalette.FRAME_RADIUS })
              .linearGradient({ angle: 90, colors: [['#3DFFFFFF', 0], ['#00FFFFFF', 1]] })
            this.tileRow(this.items.slice(0, 4), 0)
            if (this.items.length > 4) {
              this.tileRow(this.items.slice(4, 8), this.metrics.tileGap)
            }
            if (this.items.length > 8) {
              this.tileRow(this.items.slice(8, 12), this.metrics.tileGap)
            }
          }
          // 不用 width('100%') + 左右 margin：总宽会超出父容器、右侧被裁切
          // （真机分类页截图缺陷）。左右留白交给外层 padding，框体自身满宽。
          .width('100%')
          .padding({
            left: this.metrics.framePad, right: this.metrics.framePad,
            top: 6, bottom: 22
          })
          .backgroundColor(PagePalette.FRAME_BG)
          .border({ width: 1, color: PagePalette.FRAME_BORDER })
          .borderRadius(PagePalette.FRAME_RADIUS)
          .shadow({ radius: 16, color: '#30000000', offsetX: 0, offsetY: 8 })
          .margin({ top: 6, bottom: 20 })
        }
        .width('100%')
        .padding({ left: this.metrics.pagePad, right: this.metrics.pagePad })
        .layoutWeight(1)
        .align(Alignment.Top)
      }

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
