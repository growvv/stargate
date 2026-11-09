/**
 * 目录编辑器（B3′ 第一期最小配置）：只做分类内条目顺序调整。
 * 明确不做：分类增删改（IOS_CATEGORY_SPEC 系统预置）、收藏/置顶（B1）、
 * 手动添加自定义入口、推荐开关（B2）、用量查看/清空（D4）。
 */
export class CatalogEditor {
  private orders: Map<string, string[]> = new Map();

  /** 调整某类目内的条目顺序；不新增类目、不改类目集合。 */
  reorderCategory(name: string, ids: string[]): void {
    this.orders.set(name, ids.slice());
  }

  /** 读取某类目已存的顺序；未设置返回空数组。 */
  orderFor(name: string): string[] {
    const ids = this.orders.get(name);
    return ids ? ids.slice() : [];
  }

  /** 已配置顺序的类目名（仅用于断言「没有凭空新增类目」）。 */
  categoryNames(): string[] {
    const out: string[] = [];
    this.orders.forEach((_ids, name) => { out.push(name); });
    return out;
  }
}

export default CatalogEditor;
