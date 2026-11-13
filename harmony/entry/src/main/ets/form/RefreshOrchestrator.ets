import type common from '@ohos.app.ability.common';
import { CapabilityRepository } from '../data/CapabilityRepository';
import { AppTemplateCatalog } from '../data/AppTemplateCatalog';
import type { AppTemplateEntry } from '../data/AppTemplateCatalog';
import { InstalledProbe, BundleSchemeProbe, BundlePresenceProbe } from '../data/InstalledProbe';
import type { SchemeProbe, RouteProbe, PresenceProbe } from '../data/InstalledProbe';
import { RecentAdditions } from '../recommend/RecentAdditions';
import { EffectiveCatalog } from '../data/EffectiveCatalog';
import { CatalogAvailability } from '../data/CatalogAvailability';
import { CatalogDiff } from '../data/CatalogDiff';
import type { CatalogDiffResult, InstallSnapshot } from '../data/CatalogDiff';
import { InstallSnapshotStore } from '../data/InstallSnapshotStore';
import type { AtomicFunction } from '../model/AtomicFunction';
import type { UsageSnapshot } from '../data/UsageStore';
import { UsageStore } from '../data/UsageStore';
import { CardBinding } from './CardBinding';
import type { CardBindingData } from './CardBinding';

/** Pure input for one install-aware refresh pass. */
export interface RefreshInput {
  l1: AtomicFunction[];
  templates: AppTemplateEntry[];
  probe: SchemeProbe;
  /** 「最近添加」探测：探测能力库条目所属 App 当前是否可打开。缺省 = 不探测。 */
  routeProbe?: RouteProbe;
  /** 安装态探针（按包名问系统）；缺省 = 只用链接探测。 */
  presence?: PresenceProbe;
  /**
   * 是否维护「最近添加」的首次见到时间表。缺省 true（保持既有语义：传了
   * routeProbe 就统计）。只有卡片侧需要这张表；搜索 / 分类 / 配置页把目录
   * 读出来即可，不必因为打开页面就改写用户的时间表。
   */
  trackRecent?: boolean;
  prev: InstallSnapshot;
  usage: UsageSnapshot;
  now: number;
  formId: string;
  failure: string;
  failureAt: number;
  dark: boolean;
  blurAvailable: boolean;
  appVersionFingerprint: string;
  /** 配置页保存的类目顺序；卡片 chips 按此排序。 */
  categoryOrder?: string[];
}

export interface RefreshResult {
  binding: CardBindingData;
  snapshot: InstallSnapshot;
  diff: CatalogDiffResult;
  effective: AtomicFunction[];
  effectiveCount: number;
  /** 本次判定为未安装的 bundleName（诊断用，也可用于设置页提示）。 */
  missingBundles: string[];
  /** 判定来源：presence / link / none。 */
  availabilitySource: string;
}

/**
 * Single directory gate for the card and all UIAbility pages.
 * The resolve method is deliberately SDK-free so the install/debounce policy
 * remains testable; only effectiveRepository crosses the Harmony boundary.
 */
export class RefreshOrchestrator {
  static resolve(input: RefreshInput): RefreshResult {
    const probed = InstalledProbe.installedIds(input.templates, input.probe);
    const allIds: string[] = input.templates
      .filter((t: AppTemplateEntry) => t.scheme.length > 0)
      .map((t: AppTemplateEntry) => t.id)
      .sort();
    const versionChanged = input.appVersionFingerprint.length > 0 &&
      input.appVersionFingerprint !== input.prev.appVersionFingerprint;
    const starting = versionChanged ? CatalogDiff.resetDebounce(input.prev) : input.prev;
    const snapshot = CatalogDiff.confirm(starting, probed, allIds, input.now);
    snapshot.appVersionFingerprint = input.appVersionFingerprint;
    // 「最近添加」：只有显式要求时才探测（页面取目录时不要每次按键
    // 都做跨 App canOpenLink）。首次探测建立基线 = 0；之后新出现的 App 记 now。
    // 有安装态探针时优先按包名判定 —— 覆盖 file:// / vertical 这类没有可归属
    // scheme 的条目，否则它们的 App 永远不会被认成「新安装」。
    if (input.trackRecent !== false && input.routeProbe !== undefined) {
      // 三方应用查不到安装态（getBundleInfoSync 全量返回 8521226），
      // detectedBundlesBest 会在 presence 无结论时自动退回链接探测。
      const detected: string[] = input.presence !== undefined
        ? InstalledProbe.detectedBundlesBest(input.l1, input.presence, input.routeProbe)
        : InstalledProbe.detectedBundles(input.l1, input.routeProbe);
      const firstRun = input.prev.bundlesProbedAt === 0;
      snapshot.bundleFirstSeen = RecentAdditions.mergeSeen(
        input.prev.bundleFirstSeen, detected, input.now, firstRun);
      snapshot.bundlesProbedAt = input.now;
    }
    const diff = CatalogDiff.diff(input.prev.installedIds, snapshot.installedIds);

    // ── 唯一收敛点：L0 准入 + 当前设备安装态/可用性 ────────────────────
    // 先取 L0 并排序，只判定一次；判定结果同时用于过滤和诊断字段，
    // 避免同一批 scheme 在一次刷新里被探测两遍。
    const l0: AtomicFunction[] = EffectiveCatalog.l0Sorted(input.l1);
    const availability = input.routeProbe !== undefined
      ? CatalogAvailability.evaluate(l0, input.routeProbe, input.presence)
      : undefined;
    const effective: AtomicFunction[] = availability !== undefined && availability.probeAvailable
      ? EffectiveCatalog.keep(l0, new Set<string>(availability.availableIds))
      : l0;

    const binding = CardBinding.compose(CapabilityRepository.fromItems(effective), input.usage,
      input.now, input.formId, input.failure, input.dark, input.blurAvailable, input.failureAt,
      input.categoryOrder, snapshot.bundleFirstSeen);
    return {
      binding: binding,
      snapshot: snapshot,
      diff: diff,
      effective: effective,
      effectiveCount: effective.length,
      missingBundles: availability !== undefined ? availability.missingBundles : [],
      availabilitySource: availability !== undefined ? availability.source : 'none'
    };
  }

  /**
   * Production boundary. It probes declared schemes, applies the two-sample
   * debounce, persists the snapshot, and returns the one effective directory.
   * Pages and launch code must use this method instead of raw capabilities.json.
   */
  static effectiveRepository(context: common.Context, detectBundles: boolean = false): CapabilityRepository {
    const l1Repo = CapabilityRepository.fromContextSync(context);
    const templates = AppTemplateCatalog.fromContextSync(context).entries();
    const store = InstallSnapshotStore.fromContextSync(context);
    const prev = store.load();
    const presence: PresenceProbe = new BundlePresenceProbe();
    const result = RefreshOrchestrator.resolve({
      l1: l1Repo.itemsSnapshot(),
      templates: templates,
      probe: new BundleSchemeProbe(),
      // 安装态收敛对页面与卡片都必做：用户点开搜索页时看到的必须也是
      // 本机真实可用的条目。trackRecent 只控制是否维护「最近添加」时间表。
      routeProbe: new BundleSchemeProbe(),
      presence: presence,
      trackRecent: detectBundles,
      prev: prev,
      // The repository pass only needs a neutral ranking input. Use the real
      // nominal UsageStore type so ArkTS does not rely on structural typing.
      usage: new UsageStore(),
      now: Date.now(),
      formId: '',
      failure: '',
      failureAt: 0,
      dark: false,
      blurAvailable: true,
      appVersionFingerprint: ''
    });
    store.save(result.snapshot);
    return CapabilityRepository.fromItems(result.effective);
  }
}

export default RefreshOrchestrator;
