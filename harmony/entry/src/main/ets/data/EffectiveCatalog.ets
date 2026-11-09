import type { AtomicFunction } from '../model/AtomicFunction';
import { isL0 } from '../model/AtomicFunction';
import type { AppTemplateEntry } from './AppTemplateCatalog';

/**
 * L0-only gate for the card and all UIAbility pages (形态 A Spec §4.2).
 *
 * 只有真机截图确认落点的条目（isL0）能进入可直接点击目录。模板候选与安装
 * 快照仍由 RefreshOrchestrator / InstallSnapshotStore 维护（P7 的安装感知不废），
 * 但**任何** template/rea/injection 条目都不得生成卡片；也不再按 appName 隐藏
 * 已验证条目。这样即使 D5 外部可替换配置被塞进未验证条目，卡片也不会冒出来。
 *
 * build() 的三个参数签名保持不变（RefreshOrchestrator.resolve 依赖）；templates
 * 与 installedIds 保留在签名里以承接安装感知链路，但不参与输出构造。
 */
export class EffectiveCatalog {
  static build(l1: AtomicFunction[], _templates: AppTemplateEntry[],
    _installedIds: Set<string>): AtomicFunction[] {
    return l1.filter(isL0).slice().sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  }
}

export default EffectiveCatalog;
