import router from '@ohos.router';
import type common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { RefreshOrchestrator } from '../form/RefreshOrchestrator';
import { SearchFilter } from '../data/SearchFilter';
import { LaunchDispatcher } from '../launch/LaunchDispatcher';
import { createVerticalStarter } from '../launch/VerticalStarter';
import { UsageStore } from '../data/UsageStore';
import { BrandMark } from '../form/BrandMark';
import { BrandLogo } from '../form/BrandLogo';
import { PagePalette } from '../form/PagePalette';
import type { AtomicFunction } from '../model/AtomicFunction';

/**
 * 分类功能页（点卡片分类 chip 打开）—— 精准复刻 iOS「展开文件夹」（2026-11-08）。
 *
 * 参考图：蓝→青→蓝绿浅色壁纸 + 带阴影的白色大标题 + 4 列 App 图标网格。
 * 与首页卡片风格统一：外层浅色玻璃「文件夹框」内嵌功能图标框（嵌套框结构），
 * 每个功能用独立圆角框划分，绝不用普通列表。
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
    const r = await LaunchDispatcher.launch(fn, starter, this.buildUsage(), verticalStarter);
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
            .borderRadius(PagePalette.TILE_RADIUS)
        } else {
          Column()
            .width('100%').height('100%')
            .borderRadius(PagePalette.TILE_RADIUS)
            .backgroundColor(BrandMark.forApp(fn.appName, fn.label).bg)
          Column()
            .width('100%').height('42%')
            .borderRadius({ topLeft: PagePalette.TILE_RADIUS, topRight: PagePalette.TILE_RADIUS })
            .linearGradient({ angle: 90, colors: [['#33FFFFFF', 0], ['#00FFFFFF', 1]] })
          Text(BrandMark.forApp(fn.appName, fn.label).glyph)
            .fontSize(32).fontWeight(FontWeight.Bold)
            .fontColor(BrandMark.forApp(fn.appName, fn.label).fg)
            .textShadow({ radius: 3, color: '#40000000', offsetX: 0, offsetY: 1 })
        }
      }
      .width(PagePalette.TILE_SIZE)
      .height(PagePalette.TILE_SIZE)
      .borderRadius(PagePalette.TILE_RADIUS)
      .border({ width: 0.6, color: PagePalette.TILE_BORDER })
      .shadow({ radius: 8, color: '#30000000', offsetX: 0, offsetY: 3 })
      .clip(true)
      Text(fn.label).fontSize(12).fontColor(PagePalette.TEXT).maxLines(1)
        .textAlign(TextAlign.Center)
        .textShadow({ radius: 3, color: PagePalette.SHADOW, offsetX: 0, offsetY: 1 })
        .margin({ top: 6 })
        .width(PagePalette.TILE_SIZE + 16)
      Text(fn.hint ? fn.appName + ' · ' + fn.hint : fn.appName)
        .fontSize(10).fontColor(PagePalette.TEXT_SUB).maxLines(1)
        .textAlign(TextAlign.Center).width(PagePalette.TILE_SIZE + 16)
    }
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
    .justifyContent(FlexAlign.SpaceEvenly)
    .width('100%')
    .margin({ top: top })
  }

  build() {
    Column() {
      // ── 顶栏 ──────────────────────────────────────────────────────
      Row() {
        Text('‹ 返回').fontSize(15).fontColor(PagePalette.TEXT)
          .textShadow({ radius: 4, color: PagePalette.SHADOW, offsetX: 0, offsetY: 1 })
          .onClick(() => { router.back(); })
        Blank()
      }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 4 })

      // ── 展开文件夹式大标题（参考图） ──────────────────────────────
      Text(this.category)
        .fontSize(34).fontWeight(FontWeight.Bold).fontColor(PagePalette.TEXT)
        .textShadow({ radius: 8, color: PagePalette.SHADOW, offsetX: 0, offsetY: 2 })
        .margin({ left: 24, bottom: 12 })

      // ── 浅色磨砂胶囊搜索栏（外层 padding 内缩，不用满宽 + margin） ──
      Row() {
        Row() {
          Text('⌕').fontSize(18).fontColor(PagePalette.TEXT_SUB).margin({ right: 8 })
          TextInput({ placeholder: '搜索功能 / App' })
            .onChange((v: string) => { this.query = v; this.reload(); })
            .fontSize(14)
            .fontColor(PagePalette.TEXT)
            .placeholderColor(PagePalette.TEXT_DIM)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 11, bottom: 11 })
        .backgroundColor(PagePalette.FRAME_BG)
        .border({ width: 1, color: PagePalette.FRAME_BORDER })
        .borderRadius(22)
      }
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 14 })

      if (this.items.length === 0) {
        // 诚实空态
        Column() {
          Text('▦').fontSize(40).fontColor(PagePalette.TEXT_SUB)
          Text('该分类暂无可用功能').fontSize(15).fontColor(PagePalette.TEXT_SUB).margin({ top: 10 })
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
              this.tileRow(this.items.slice(4, 8), PagePalette.TILE_GAP)
            }
            if (this.items.length > 8) {
              this.tileRow(this.items.slice(8, 12), PagePalette.TILE_GAP)
            }
          }
          // 不用 width('100%') + 左右 margin：总宽会超出父容器、右侧被裁切
          // （真机分类页截图缺陷）。左右留白交给外层 padding，框体自身满宽。
          .width('100%')
          .padding({ left: 14, right: 14, top: 6, bottom: 22 })
          .backgroundColor(PagePalette.FRAME_BG)
          .border({ width: 1, color: PagePalette.FRAME_BORDER })
          .borderRadius(PagePalette.FRAME_RADIUS)
          .shadow({ radius: 16, color: '#30000000', offsetX: 0, offsetY: 8 })
          .margin({ top: 6, bottom: 20 })
        }
        .width('100%')
        .padding({ left: 18, right: 18 })
        .layoutWeight(1)
        .align(Alignment.Top)
      }

      if (this.message) {
        Row() {
          Text('●').fontSize(9).fontColor(PagePalette.RED).margin({ right: 6 })
          Text(this.message).fontSize(12).fontColor(PagePalette.TEXT)
        }
        .padding(12)
        .backgroundColor(PagePalette.FRAME_BG)
        .border({ width: 1, color: PagePalette.FRAME_BORDER })
        .borderRadius(14)
        .margin({ left: 18, right: 18, bottom: 14 })
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 150,
      colors: [[PagePalette.BG[0], 0], [PagePalette.BG[1], 0.45], [PagePalette.BG[2], 1]]
    })
  }
}
