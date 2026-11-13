import router from '@ohos.router';
import { ConfigAccess } from '../data/ConfigAccess';
import { CATEGORIES } from '../model/AtomicFunction';
import { CategoryOrder } from '../data/CategoryOrder';
import { CategoryOrderStore } from '../data/CategoryOrderStore';
import { PagePalette } from '../form/PagePalette';
import { PageMetricsCalc } from '../form/PageMetrics';
import type { PageMetrics } from '../form/PageMetrics';

/**
 * 配置页 —— 与首页卡片 / 搜索页 / 分类页风格统一对齐（2026-11-08）。
 * 浅色蓝→青→蓝绿壁纸 + 外层玻璃「文件夹框」内嵌分类「功能框」，
 * 绝不用普通列表。B3′ 第一期最小配置：分类排序 + 能力库替换入口。
 */
@Entry
@Component
struct ConfigPage {
  @State systemEditEntry: boolean = false;
  @State categories: string[] = CATEGORIES.slice();
  @State notice: string = '';
  /** 按容器宽度推导出的内页尺寸；首帧用手机基准，onAreaChange 后更新。 */
  @State metrics: PageMetrics = PageMetricsCalc.baseline();

  private store: CategoryOrderStore = CategoryOrderStore.fromMemory();

  aboutToAppear(): void {
    this.notice = ConfigAccess.firstAddGuideEnabled(this.systemEditEntry)
      ? '首次添加引导：能力库为空时点卡片「配置」进入本页'
      : '配置页';
    // 读取用户上次保存的类目顺序（未保存过 = 系统默认顺序）。
    this.store = CategoryOrderStore.fromContextSync(getContext(this));
    this.categories = this.store.load();
  }

  /** 单个分类功能框（内层框），嵌套在外层文件夹框里。 */
  @Builder
  categoryTile(name: string) {
    Row() {
      Text(name).fontSize(this.metrics.rowFont).fontWeight(FontWeight.Medium).fontColor(PagePalette.TEXT)
      Blank()
      // 拖拽把手：List 开启 editMode 后，长按整行即可拖动排序。
      Text('≡').fontSize(this.metrics.rowFont * 1.15).fontColor(PagePalette.TEXT_SUB)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 13, bottom: 13 })
    .backgroundColor(PagePalette.TILE_BG)
    .border({ width: 0.6, color: PagePalette.TILE_BORDER })
    .borderRadius(PagePalette.TILE_RADIUS)
  }

  /** 拖拽跟随预览（List onItemDragStart 必须返回 CustomBuilder）。 */
  @Builder
  dragOverlay(name: string) {
    Row() {
      Text(name).fontSize(this.metrics.rowFont).fontWeight(FontWeight.Medium).fontColor(PagePalette.TEXT)
      Blank()
      Text('≡').fontSize(this.metrics.rowFont * 1.15).fontColor(PagePalette.TEXT_SUB)
    }
    // 拖拽预览宽度按页面宽度的一半左右取，不写死 240 —— 平板上也能跟手。
    .width(this.metrics.widthVp * 0.62)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(PagePalette.FRAME_BG)
    .border({ width: 1, color: PagePalette.FRAME_BORDER })
    .borderRadius(PagePalette.TILE_RADIUS)
    .shadow({ radius: 14, color: '#40000000', offsetX: 0, offsetY: 6 })
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(this.metrics.rowFont).fontColor(PagePalette.TEXT)
          .textShadow({ radius: 4, color: PagePalette.SHADOW, offsetX: 0, offsetY: 1 })
          .onClick(() => { router.back(); })
        Blank()
      }.width('100%').padding({
        left: this.metrics.pagePad, right: this.metrics.pagePad, top: 18, bottom: 4
      })

      Text('设置')
        .fontSize(this.metrics.titleFont).fontWeight(FontWeight.Bold).fontColor(PagePalette.TEXT)
        .textShadow({ radius: 8, color: PagePalette.SHADOW, offsetX: 0, offsetY: 2 })
        .textAlign(TextAlign.Start)
        .width('100%')
        .padding({ left: this.metrics.pagePad })
        .margin({ bottom: 6 })

      Text(this.notice).fontSize(this.metrics.rowSubFont).fontColor(PagePalette.TEXT_SUB)
        .margin({ left: this.metrics.pagePad, bottom: 16 })

      Row() {
        Text('能力探索').fontSize(this.metrics.rowFont).fontWeight(FontWeight.Medium).fontColor(PagePalette.TEXT)
        Blank()
        Text('查看入口与探测状态 ›').fontSize(this.metrics.rowSubFont).fontColor(PagePalette.TEXT_SUB)
      }
      .width('100%').padding({ left: 16, right: 16, top: 13, bottom: 13 })
      .backgroundColor(PagePalette.TILE_BG)
      .border({ width: 0.6, color: PagePalette.TILE_BORDER })
      .borderRadius(PagePalette.TILE_RADIUS)
      .margin({ left: 18, right: 18, bottom: 16 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/CapabilityExplorerPage' });
      })

      Text('分类（长按拖动排序，顺序会同步到卡片）')
        .fontSize(this.metrics.rowSubFont).fontColor(PagePalette.TEXT_SUB)
        .margin({ left: 24, bottom: 8 })

      // ── 外层玻璃文件夹框，内嵌可拖拽排序的分类列表 ──
      // 旧版用 Flex 排两列 + 点「≡」无效：改为 List.editMode(true) + onItemDrop，
      // 长按任意分类行即可拖动，落点处插入并持久化到 CategoryOrderStore。
      List({ space: 8 }) {
        ForEach(this.categories, (name: string) => {
          ListItem() {
            this.categoryTile(name)
          }
        }, (name: string) => name)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor(PagePalette.FRAME_BG)
      .border({ width: 1, color: PagePalette.FRAME_BORDER })
      .borderRadius(PagePalette.FRAME_RADIUS)
      .shadow({ radius: 16, color: '#30000000', offsetX: 0, offsetY: 8 })
      .margin({ left: 18, right: 18, bottom: 12 })
      .scrollBar(BarState.Off)
      .editMode(true)
      .onItemDragStart((event: ItemDragInfo, itemIndex: number) => {
        return this.dragOverlay(this.categories[itemIndex]);
      })
      .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
        if (!isSuccess || insertIndex < 0 || insertIndex >= this.categories.length) return;
        this.categories = CategoryOrder.move(this.categories, itemIndex, insertIndex);
        this.store.save(this.categories);
      })

      // D5 能力库替换入口（外层玻璃框）
      Column() {
        Text('能力库').fontSize(this.metrics.rowSubFont).fontColor(PagePalette.TEXT).margin({ bottom: 6 })
        Text('/data/storage/el2/base/haps/entry/files/capabilities.json')
          .fontSize(this.metrics.rowSubFont - 1).fontColor(PagePalette.TEXT)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor(PagePalette.FRAME_BG)
      .border({ width: 1, color: PagePalette.FRAME_BORDER })
      .borderRadius(PagePalette.FRAME_RADIUS)
      .shadow({ radius: 12, color: '#30000000', offsetX: 0, offsetY: 5 })
      .margin({ bottom: 20 })
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
