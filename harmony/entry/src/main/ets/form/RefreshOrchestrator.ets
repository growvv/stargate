import type common from '@ohos.app.ability.common';
import { CapabilityRepository } from '../data/CapabilityRepository';
import { AppTemplateCatalog } from '../data/AppTemplateCatalog';
import type { AppTemplateEntry } from '../data/AppTemplateCatalog';
import { InstalledProbe, BundleSchemeProbe } from '../data/InstalledProbe';
import type { SchemeProbe, RouteProbe } from '../data/InstalledProbe';
import { RecentAdditions } from '../recommend/RecentAdditions';
import { EffectiveCatalog } from '../data/EffectiveCatalog';
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
    // 「最近添加」：只有显式传入 routeProbe 时才探测（页面取目录时不要每次按键
    // 都做跨 App canOpenLink）。首次探测建立基线 = 0；之后新出现的 App 记 now。
    if (input.routeProbe !== undefined) {
      const detected = InstalledProbe.detectedBundles(input.l1, input.routeProbe);
      const firstRun = input.prev.bundlesProbedAt === 0;
      snapshot.bundleFirstSeen = RecentAdditions.mergeSeen(
        input.prev.bundleFirstSeen, detected, input.now, firstRun);
      snapshot.bundlesProbedAt = input.now;
    }
    const diff = CatalogDiff.diff(input.prev.installedIds, snapshot.installedIds);
    const effective = EffectiveCatalog.build(input.l1, input.templates, new Set<string>(snapshot.installedIds));
    const binding = CardBinding.compose(CapabilityRepository.fromItems(effective), input.usage,
      input.now, input.formId, input.failure, input.dark, input.blurAvailable, input.failureAt,
      input.categoryOrder, snapshot.bundleFirstSeen);
    return {
      binding: binding,
      snapshot: snapshot,
      diff: diff,
      effective: effective,
      effectiveCount: effective.length
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
    const result = RefreshOrchestrator.resolve({
      l1: l1Repo.itemsSnapshot(),
      templates: templates,
      probe: new BundleSchemeProbe(),
      routeProbe: detectBundles ? new BundleSchemeProbe() : undefined,
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
