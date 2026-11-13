import type { AtomicFunction } from '../model/AtomicFunction';
import { isL0 } from '../model/AtomicFunction';
import type { AppTemplateEntry } from './AppTemplateCatalog';
import { CatalogAvailability } from './CatalogAvailability';
import type { AvailabilityResult } from './CatalogAvailability';
import { RouteHonesty } from './RouteHonesty';
import type { RouteProbe, PresenceProbe } from './InstalledProbe';

/**
 * 能力目录的唯一收敛点（形态 A Spec §4.2 + 2026-11-11 换设备修复）。
 *
 * 两道过滤，顺序不能反：
 *  1. **L0 准入**：只有真机确认过落点的条目（isL0）才有资格出现。template /
 *     rea / injection 永远不进目录 —— 即使 D5 外部可替换配置被塞进未验证条目。
 *  2. **安装态 + 可用性**：按当前设备的真实安装情况收敛（CatalogAvailability）。
 *     没装的 App、声明了却打不开的入口全部剔除，用户点不到「点不开的图标」。
 *
 * 第 2 道是新加的：此前 build() 只做 L0 过滤，`installedIds` 收下就丢，
 * 于是换一台没装 WPS 的手机，WPS 图标照样在卡片上，点下去失败。
 *
 * 探针缺省或整体失效时 fail-open（CatalogAvailability 内部保证），
 * 结果退化为纯 L0 过滤，绝不会把目录清空。
 */
export class EffectiveCatalog {
  static build(l1: AtomicFunction[], _templates: AppTemplateEntry[],
    _installedIds: Set<string>, routeProbe?: RouteProbe,
    presence?: PresenceProbe): AtomicFunction[] {
    const sorted: AtomicFunction[] = EffectiveCatalog.l0Sorted(l1);
    if (!routeProbe) return sorted;
    const availability: AvailabilityResult = CatalogAvailability.evaluate(sorted, routeProbe, presence);
    if (!availability.probeAvailable) return sorted;
    const keep: Set<string> = new Set<string>(availability.availableIds);
    return sorted.filter((f: AtomicFunction) => keep.has(f.id));
  }

  /**
   * L0 条目按 id 稳定排序 + 标签与落点对齐（build 与编排层共用同一套准入顺序）。
   *
   * RouteHonesty 在这里而不是在 UI 层：卡片、分类页、搜索页、直达分发全部读
   * 同一个 effective 目录，只有在这一处改名，才不会出现「卡片写着打开抖音、
   * 搜索页还写着付款」的不一致。详见 RouteHonesty 注释（裸 scheme 只到首页）。
   */
  static l0Sorted(l1: AtomicFunction[]): AtomicFunction[] {
    const sorted: AtomicFunction[] = l1.filter(isL0).slice()
      .sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
    return RouteHonesty.apply(sorted).items;
  }

  /** 按判定结果保留条目（保持排序）。 */
  static keep(sorted: AtomicFunction[], availableIds: Set<string>): AtomicFunction[] {
    return sorted.filter((f: AtomicFunction) => availableIds.has(f.id));
  }

  /**
   * 只做判定、不改顺序：供 RefreshOrchestrator 复用一次探测结果，
   * 避免同一次刷新里对同一批 scheme 探测两遍。
   */
  static availability(items: AtomicFunction[], routeProbe: RouteProbe,
    presence?: PresenceProbe): AvailabilityResult {
    return CatalogAvailability.evaluate(items, routeProbe, presence);
  }
}

export default EffectiveCatalog;
