import { CATEGORIES } from '../model/AtomicFunction';

/**
 * 分类排序的纯逻辑（无 SDK 依赖）。
 * 卡片 widgets.abc 与配置页共用；preferences 读写放在 CategoryOrderStore。
 */
export class CategoryOrder {
  static normalize(order: string[]): string[] {
    const out: string[] = [];
    if (order) {
      for (const name of order) {
        if (CATEGORIES.indexOf(name) >= 0 && out.indexOf(name) < 0) out.push(name);
      }
    }
    for (const name of CATEGORIES) {
      if (out.indexOf(name) < 0) out.push(name);
    }
    return out;
  }

  /** 把 from 位置的类目拖到 to 位置（越界钳制），返回新的合法顺序。 */
  static move(order: string[], from: number, to: number): string[] {
    const out: string[] = CategoryOrder.normalize(order);
    if (from < 0 || from >= out.length) return out;
    const target: number = to < 0 ? 0 : (to >= out.length ? out.length - 1 : to);
    if (from === target) return out;
    const moved: string = out.splice(from, 1)[0];
    out.splice(target, 0, moved);
    return out;
  }
}

export default CategoryOrder;
