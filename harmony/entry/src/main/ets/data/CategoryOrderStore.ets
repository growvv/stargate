import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';
import { CategoryOrder } from './CategoryOrder';

/**
 * 分类排序持久化（B3′ 配置页，2026-11-09 用户反馈「拖不动」）。
 *
 * 只允许对系统预置的 9 个类目排序：未知名字丢弃、重复去掉、缺失的按默认
 * 顺序补齐 —— 保证任何情况下都不会出现「新增/丢失类目」。
 * 排序结果供配置页展示，也下发给卡片分类 chips（WidgetCardData）。
 */
const STORE_NAME: string = 'atomic_function_category_order';
const ORDER_KEY: string = 'order';

export class CategoryOrderStore {
  private order: string[];
  private pref: preferences.Preferences | undefined = undefined;

  private constructor(order: string[], pref?: preferences.Preferences) {
    this.order = CategoryOrder.normalize(order);
    this.pref = pref;
  }

  static fromMemory(order?: string[]): CategoryOrderStore {
    return new CategoryOrderStore(order ?? []);
  }

  static fromContextSync(context: common.Context): CategoryOrderStore {
    try {
      const pref = preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw = pref.getSync(ORDER_KEY, '[]');
      const parsed: string[] = typeof raw === 'string' ? JSON.parse(raw) as string[] : [];
      return new CategoryOrderStore(Array.isArray(parsed) ? parsed : [], pref);
    } catch (_err) {
      return new CategoryOrderStore([]);
    }
  }

  load(): string[] {
    return this.order.slice();
  }

  save(order: string[]): void {
    this.order = CategoryOrder.normalize(order);
    if (!this.pref) return;
    try {
      this.pref.putSync(ORDER_KEY, JSON.stringify(this.order));
      this.pref.flushSync();
    } catch (_err) {
      // 内存状态仍是本次进程的权威顺序；持久化失败不回滚 UI。
    }
  }
}

export default CategoryOrderStore;
