import router from '@ohos.router';
import type common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { RefreshOrchestrator } from '../form/RefreshOrchestrator';
import { LaunchDispatcher } from '../launch/LaunchDispatcher';
import { createVerticalStarter } from '../launch/VerticalStarter';
import { UsageStore } from '../data/UsageStore';
import { CapabilityExplorer } from '../data/CapabilityExplorer';
import type { ExplorerSummary } from '../data/CapabilityExplorer';
import type { AtomicFunction } from '../model/AtomicFunction';
import { BrandMark } from '../form/BrandMark';
import { BrandLogo } from '../form/BrandLogo';
import { PagePalette } from '../form/PagePalette';
import { DiscoveryStats } from '../data/DiscoveryStats';
import { DiscoveryCandidateCatalog } from '../data/DiscoveryCandidateCatalog';
import type { DiscoveryCandidate } from '../data/DiscoveryCandidateCatalog';

/**
 * 能力探索页：把“可以直接使用什么”和“还需要怎么探测”放在同一处。
 * 能力库是唯一事实来源；REA/UI Test 只作为带来源的候选，不在页面上伪装成已验证入口。
 */
@Entry
@Component
struct CapabilityExplorerPage {
  @State items: AtomicFunction[] = [];
  @State summary: ExplorerSummary = {
    total: 0, verified: 0, rea: 0, uiTest: 0, manual: 0, unknown: 0
  };
  @State notice: string = '';
  @State launchNotice: string = '';
  @State candidates: DiscoveryCandidate[] = [];
  @State candidateQuery: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  private async reload(): Promise<void> {
    try {
      const repo = RefreshOrchestrator.effectiveRepository(getContext(this));
      const next = await repo.listAll();
      this.items = next;
      this.summary = CapabilityExplorer.summarize(next);
      this.candidates = DiscoveryCandidateCatalog.fromContextSync(getContext(this));
      this.notice = next.length === 0
        ? '能力库为空：先用公开入口、REA 或 UI Test 探针产出候选，再写入 capabilities.json。'
        : '';
    } catch (_err) {
      this.items = [];
      this.summary = CapabilityExplorer.summarize([]);
      this.candidates = [];
      this.notice = '能力库读取失败，已保留空态；请检查配置文件格式。';
    }
  }

  private openAll(): void {
    router.pushUrl({ url: 'pages/AllFunctionsPage' });
  }

  private openConfig(): void {
    router.pushUrl({ url: 'pages/ConfigPage' });
  }

  private filteredCandidates(): DiscoveryCandidate[] {
    return DiscoveryCandidateCatalog.filter(this.candidates, this.candidateQuery);
  }

  private buildUsage(): UsageStore {
    try {
      const pref = preferences.getPreferencesSync(getContext(this), { name: 'atomic_function_usage' });
      return UsageStore.withPreferencesSync(pref);
    } catch (_err) {
      return new UsageStore();
    }
  }

  /** 每行右侧的「打开 ›」跳转链接：与卡片点击走同一条直达链路。 */
  private async onOpen(item: AtomicFunction): Promise<void> {
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
    const r = await LaunchDispatcher.launch(item, starter, this.buildUsage(), verticalStarter);
    this.launchNotice = r.ok ? '' : LaunchDispatcher.onFailure(item, r);
  }

  @Builder
  statTile(label: string, value: number, accent: string) {
    Column() {
      Text(value.toString()).fontSize(24).fontWeight(FontWeight.Bold).fontColor(accent)
      Text(label).fontSize(11).fontColor(PagePalette.TEXT_SUB).margin({ top: 3 })
    }
    .width('31%')
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(PagePalette.FRAME_BG)
    .border({ width: 1, color: PagePalette.FRAME_BORDER })
    .borderRadius(16)
  }

  @Builder
  pipelineStep(index: string, title: string, detail: string, color: string) {
    Row() {
      Text(index).fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFFFF')
        .textAlign(TextAlign.Center)
        .width(24).height(24).borderRadius(12).backgroundColor(color)
      Column() {
        Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor(PagePalette.TEXT)
        Text(detail).fontSize(11).fontColor(PagePalette.TEXT_SUB).margin({ top: 2 })
      }.alignItems(HorizontalAlign.Start).margin({ left: 10 })
    }.width('100%').margin({ bottom: 10 })
  }

  @Builder
  capabilityRow(item: AtomicFunction) {
    Row() {
      Stack() {
        if (BrandMark.forApp(item.appName, item.label).hasLogo) {
          Image(BrandLogo.image(BrandMark.forApp(item.appName, item.label).key))
            .width('100%').height('100%').objectFit(ImageFit.Cover).borderRadius(12)
        } else {
          Column().width('100%').height('100%').borderRadius(12)
            .backgroundColor(BrandMark.forApp(item.appName, item.label).bg)
          Text(BrandMark.forApp(item.appName, item.label).glyph)
            .fontSize(22).fontWeight(FontWeight.Bold)
            .fontColor(BrandMark.forApp(item.appName, item.label).fg)
        }
      }.width(42).height(42).clip(true)
      Column() {
        Row() {
          Text(item.label).fontSize(15).fontWeight(FontWeight.Medium).fontColor(PagePalette.TEXT)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          Text(CapabilityExplorer.levelLabel(CapabilityExplorer.levelOf(item.source)))
            .fontSize(11).fontColor(PagePalette.TEXT_SUB).margin({ left: 6 })
          // 用户 2026-11-09：每条能力右侧要有单独可点的跳转链接。
          Text('打开 ›')
            .fontSize(12)
            .fontColor(PagePalette.TEXT)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(PagePalette.FRAME_BG)
            .border({ width: 0.6, color: PagePalette.FRAME_BORDER })
            .borderRadius(12)
            .margin({ left: 8 })
            .onClick(() => { this.onOpen(item); })
        }.width('100%')
        Row() {
          Text(item.appName + ' · ' + item.category).fontSize(12).fontColor(PagePalette.TEXT_SUB)
          Blank()
          Text(CapabilityExplorer.routeLabel(item.route)).fontSize(11).fontColor(PagePalette.TEXT_DIM)
        }.width('100%').margin({ top: 4 })
        Text(CapabilityExplorer.sourceLabel(item.source)).fontSize(11).fontColor(PagePalette.TEXT_DIM)
          .margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .backgroundColor(PagePalette.TILE_BG)
    .border({ width: 0.6, color: PagePalette.TILE_BORDER })
    .borderRadius(14)
    .margin({ bottom: 8 })
  }

  @Builder
  candidateRow(candidate: DiscoveryCandidate) {
    Row() {
      Stack() {
        if (BrandMark.forApp(candidate.appName, candidate.bundleName).hasLogo) {
          Image(BrandLogo.image(BrandMark.forApp(candidate.appName, candidate.bundleName).key))
            .width('100%').height('100%').objectFit(ImageFit.Cover).borderRadius(12)
        } else {
          Column().width('100%').height('100%').borderRadius(12)
            .backgroundColor(BrandMark.forApp(candidate.appName, candidate.bundleName).bg)
          Text(BrandMark.forApp(candidate.appName, candidate.bundleName).glyph)
            .fontSize(21).fontWeight(FontWeight.Bold)
            .fontColor(BrandMark.forApp(candidate.appName, candidate.bundleName).fg)
        }
      }.width(40).height(40).clip(true)
      Column() {
        Row() {
          Text(candidate.appName).fontSize(15).fontWeight(FontWeight.Medium).fontColor(PagePalette.TEXT)
          Blank()
          Text(DiscoveryCandidateCatalog.statusLabel(candidate.status))
            .fontSize(11).fontColor(candidate.status === 'declared' ? PagePalette.BLUE : PagePalette.TEXT_SUB)
        }.width('100%')
        Row() {
          Text(candidate.category + ' · ' + candidate.entrypointCount + ' 条线索')
            .fontSize(12).fontColor(PagePalette.TEXT_SUB)
          Blank()
          Text(DiscoveryCandidateCatalog.sourceLabel(candidate.sourceLayer))
            .fontSize(11).fontColor(PagePalette.TEXT_DIM)
        }.width('100%').margin({ top: 4 })
        Text(DiscoveryCandidateCatalog.hintPreview(candidate))
          .fontSize(11).fontColor(PagePalette.TEXT_DIM).maxLines(1)
          .margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 10 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(PagePalette.TILE_BG)
    .border({ width: 0.6, color: PagePalette.TILE_BORDER })
    .borderRadius(14)
    .margin({ bottom: 8 })
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(15).fontColor(PagePalette.TEXT)
          .textShadow({ radius: 4, color: PagePalette.SHADOW, offsetX: 0, offsetY: 1 })
          .onClick(() => { router.back(); })
        Blank()
        Text('刷新').fontSize(13).fontColor(PagePalette.TEXT_SUB).onClick(() => { this.reload(); })
      }.width('100%').padding({ left: 20, right: 20, top: 18, bottom: 4 })

      Text('能力探索').fontSize(32).fontWeight(FontWeight.Bold).fontColor(PagePalette.TEXT)
        .textShadow({ radius: 8, color: PagePalette.SHADOW, offsetX: 0, offsetY: 2 })
        .margin({ left: 24, bottom: 4 })
      Text('先看已开放入口，再追踪未开放 App 的线索')
        .fontSize(13).fontColor(PagePalette.TEXT_SUB).margin({ left: 24, bottom: 14 })

      Column() {
        Text(DiscoveryStats.headline()).fontSize(11).fontColor(PagePalette.TEXT)
        Text(DiscoveryStats.boundary()).fontSize(11).fontColor(PagePalette.TEXT_SUB)
          .margin({ top: 4 })
      }
      .width('100%').alignItems(HorizontalAlign.Start)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(PagePalette.FRAME_BG)
      .border({ width: 1, color: PagePalette.FRAME_BORDER })
      .borderRadius(14).margin({ left: 18, right: 18, bottom: 12 })

      Row() {
        this.statTile('全部能力', this.summary.total, PagePalette.TEXT)
        this.statTile('可直接进入', this.summary.verified, PagePalette.GREEN)
        this.statTile('待探测线索', this.candidates.length, PagePalette.BLUE)
      }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ bottom: 12 })

      Row() {
        Button('全部功能').fontSize(13).fontColor(PagePalette.TEXT).backgroundColor(PagePalette.FRAME_BG)
          .border({ width: 1, color: PagePalette.FRAME_BORDER }).borderRadius(16)
          .layoutWeight(1).margin({ right: 6 }).onClick(() => { this.openAll(); })
        Button('能力库设置').fontSize(13).fontColor(PagePalette.TEXT).backgroundColor(PagePalette.FRAME_BG)
          .border({ width: 1, color: PagePalette.FRAME_BORDER }).borderRadius(16)
          .layoutWeight(1).margin({ left: 6 }).onClick(() => { this.openConfig(); })
      }.width('100%').padding({ left: 18, right: 18 }).margin({ bottom: 12 })

      if (this.launchNotice) {
        Row() {
          Text('●').fontSize(9).fontColor(PagePalette.RED).margin({ right: 6 })
          Text(this.launchNotice).fontSize(12).fontColor(PagePalette.TEXT).layoutWeight(1)
          Text('×').fontSize(14).fontColor(PagePalette.TEXT_SUB)
            .onClick(() => { this.launchNotice = ''; })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(PagePalette.FRAME_BG)
        .border({ width: 1, color: PagePalette.FRAME_BORDER })
        .borderRadius(14)
        .margin({ left: 18, right: 18, bottom: 10 })
      }

      Scroll() {
        Column() {
          Column() {
            Text('探索路径').fontSize(13).fontWeight(FontWeight.Medium).fontColor(PagePalette.TEXT)
              .margin({ bottom: 10 })
            this.pipelineStep('1', '公开入口', 'Shortcut / Link / Scheme，验证后可直接使用', PagePalette.GREEN)
            this.pipelineStep('2', 'REA 静态分析', '从 HAP、资源和代码中提取页面与路由线索', PagePalette.BLUE)
            this.pipelineStep('3', 'UI Test 探测', '在测试态验证隐藏页面，不把猜测写入可用目录', PagePalette.PURPLE)
            this.pipelineStep('4', '人工确认', '确认入口稳定后再沉淀到本地能力库', PagePalette.ORANGE)
          }
          .width('100%').padding(14).backgroundColor(PagePalette.FRAME_BG)
          .border({ width: 1, color: PagePalette.FRAME_BORDER }).borderRadius(PagePalette.FRAME_RADIUS)
          .shadow({ radius: 12, color: '#30000000', offsetX: 0, offsetY: 5 }).margin({ bottom: 12 })

          if (this.notice) {
            Text(this.notice).fontSize(12).fontColor(PagePalette.TEXT_SUB)
              .lineHeight(18).padding(14).width('100%')
              .backgroundColor(PagePalette.FRAME_BG).border({ width: 1, color: PagePalette.FRAME_BORDER })
              .borderRadius(14).margin({ bottom: 12 })
          }

          if (this.items.length > 0) {
            Text('能力条目').fontSize(13).fontWeight(FontWeight.Medium).fontColor(PagePalette.TEXT)
              .margin({ left: 4, bottom: 8 })
            ForEach(this.items, (item: AtomicFunction) => {
              this.capabilityRow(item)
            }, (item: AtomicFunction) => item.id)
          }

          if (this.candidates.length > 0) {
            Row() {
              Text('已发现候选').fontSize(13).fontWeight(FontWeight.Medium).fontColor(PagePalette.TEXT)
              Blank()
              Text(this.candidates.length + ' 个 App · 点击前需验证')
                .fontSize(10).fontColor(PagePalette.TEXT_SUB)
            }.width('100%').margin({ top: 10, bottom: 8 })
            Text('这些入口来自应用声明扫描；面板会保留 Scheme、Link 特性、Shortcut 和路径线索，只有截图确认落到原子页后才会进入可直接使用。')
              .fontSize(11).fontColor(PagePalette.TEXT_SUB).lineHeight(17)
              .padding(12).width('100%')
              .backgroundColor(PagePalette.FRAME_BG).border({ width: 1, color: PagePalette.FRAME_BORDER })
              .borderRadius(14).margin({ bottom: 10 })
            Row() {
              Text('⌕').fontSize(17).fontColor(PagePalette.TEXT_SUB).margin({ right: 8 })
              TextInput({ placeholder: '搜索候选 App / 包名 / Scheme / Shortcut' })
                .onChange((v: string) => { this.candidateQuery = v; })
                .fontSize(13).fontColor(PagePalette.TEXT)
                .placeholderColor(PagePalette.TEXT_DIM)
                .backgroundColor(Color.Transparent).layoutWeight(1)
            }
            .width('100%').padding({ left: 14, right: 14, top: 9, bottom: 9 })
            .backgroundColor(PagePalette.FRAME_BG)
            .border({ width: 1, color: PagePalette.FRAME_BORDER })
            .borderRadius(20).margin({ bottom: 10 })
            Text('匹配 ' + this.filteredCandidates().length + ' / ' + this.candidates.length + ' 个候选')
              .fontSize(10).fontColor(PagePalette.TEXT_SUB).margin({ left: 4, bottom: 7 })
            ForEach(this.filteredCandidates(), (candidate: DiscoveryCandidate) => {
              this.candidateRow(candidate)
            }, (candidate: DiscoveryCandidate) => candidate.id)
          }
        }.width('100%').padding({ left: 18, right: 18, bottom: 18 })
      }.width('100%').layoutWeight(1).align(Alignment.Top)
    }
    .width('100%').height('100%')
    .linearGradient({ angle: 150, colors: [[PagePalette.BG[0], 0], [PagePalette.BG[1], 0.45], [PagePalette.BG[2], 1]] })
  }
}
