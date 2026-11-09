import type { AtomicFunction } from '../model/AtomicFunction';

/**
 * D1 修复（真机 2026-11-07）：AllFunctionsPage 原用 ListItemGroup + 双层 ForEach，
 * 搜索时 ArkUI 复用旧分组里的 ListItem 不回收 —— 计数「2 项」却渲染 3 行陈旧条目。
 *
 * 修法：把分组结构拍平成「header 行 + item 行」的一维 ListItem 列表，且每个 key
 * 都带上 query。查询一变，所有 key 变化，ArkUI 不再复用旧行，彻底消除陈旧项。
 *
 * 纯逻辑、无 SDK 依赖，可被 Node 单测直接驱动。
 */
export interface FlatRow {
  /** 'header' = 分组标题行；'item' = 功能条目行。 */
  kind: string;
  /** ForEach 的 key：包含 query，保证查询变化时整表失效重建。 */
  key: string;
  /** header 行的分组字母，或 item 行的功能标签。 */
  label: string;
  /** item 行对应的原始功能（供 onClick 直达）；header 行为 undefined。 */
  fn?: AtomicFunction;
  /** header 行在扁平列表中的下标（供 A–Z 索引 scrollToIndex）。 */
  index?: number;
}

export class FlatSections {
  /**
   * 按 PinyinUtil.group 的插入顺序拍平。
   * @param groups 分组键 → 该组条目（已由 PinyinUtil.group 排好序）
   * @param query  当前搜索词；参与 key，查询变化即让旧 ListItem 全部失效
   */
  static flatten(groups: Map<string, AtomicFunction[]>, query: string = ''): FlatRow[] {
    const rows: FlatRow[] = [];
    const groupIndex = new Map<string, number>();
    let at = 0;
    groups.forEach((items: AtomicFunction[], key: string) => {
      groupIndex.set(key, at);
      const header: FlatRow = {
        kind: 'header',
        key: 'h:' + query + '|' + key,
        label: key,
        index: at
      };
      rows.push(header);
      at++;
      for (const fn of items) {
        rows.push({
          kind: 'item',
          key: 'i:' + query + '|' + key + ':' + fn.id,
          label: fn.label,
          fn: fn
        });
        at++;
      }
    });
    return rows;
  }

  /** 分组键 → 该组 header 在扁平列表中的下标，供 A–Z 索引点击跳转。 */
  static groupIndices(rows: FlatRow[]): Map<string, number> {
    const out = new Map<string, number>();
    for (const r of rows) {
      if (r.kind === 'header') out.set(r.label, r.index ?? 0);
    }
    return out;
  }
}

export default FlatSections;
