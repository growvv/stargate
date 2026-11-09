/**
 * 页面跳转参数构造器（纯函数，无 UI 依赖，卡片可安全导入）。
 * postCardAction 'router' 把 params 作为 Want 传给 EntryAbility，
 * EntryAbility 读 want.parameters.page 决定 loadContent（Task 4）。
 *
 * ArkTS 约束：`arkts-no-untyped-obj-literals` 要求对象字面量对应显式声明的
 * interface，`arkts-no-indexed-signatures` 禁用索引签名。故用下面具名接口，
 * 返回值仍是纯字符串键值对象，可直接作为 postCardAction 的 params。
 * （计划文本写 Record<string,string>，实际签名按平台约束改为具名接口，见 ledger Ruling。）
 */
export interface CategoryPageParams {
  page: string;
  category: string;
}

export interface AllPageParams {
  page: string;
}

/** 卡片功能点击 → UIAbility 侧直达（Task 5）。formId 用于失败反馈推回该卡片（I2）。 */
export interface LaunchPageParams {
  page: string;
  functionId: string;
  formId: string;
}

/** 卡片空态「配置」入口 → 最小配置页（I5：不能是死入口）。 */
export interface ConfigPageParams {
  page: string;
}

/** 能力探索页入口：展示已验证能力与 REA/UI Test 待验证线索。 */
export interface ExplorerPageParams {
  page: string;
}

/** postCardAction 'router' 的完整 action 对象。
 *  华为官方 router 事件要求 abilityName 在 action 顶层（不是 params 内），
 *  否则 form host 找不到目标 UIAbility，点击静默不跳转。 */
export interface RouterAction<T> {
  action: string;
  abilityName: string;
  params: T;
}

export class PageRouter {
  /** 把纯参数对象包成合法 router action（abilityName 固定在顶层）。 */
  static routerAction<T>(params: T): RouterAction<T> {
    const a: RouterAction<T> = {
      action: 'router',
      abilityName: 'EntryAbility',
      params: params
    };
    return a;
  }

  /** onNewWant 时若目标页发生变化，必须重新 loadContent，否则显示的是上一页。 */
  static needsContentReload(currentPage: string, nextPage: string): boolean {
    return currentPage !== nextPage && nextPage !== 'launch';
  }

  /**
   * 真机缺陷（2026-11-09）：分类页的页面路径都是 category，只比较 page 会漏掉
   * 「支付 → 购物」这类同页不同分类的切换，导致页面停在旧分类。分类变化也必须重载。
   */
  static needsContentReloadForTarget(currentPage: string, nextPage: string,
    currentCategory: string, nextCategory: string): boolean {
    if (nextPage === 'launch') return false;
    if (currentPage !== nextPage) return true;
    return nextPage === 'category' && currentCategory !== nextCategory;
  }
  static categoryParams(category: string): CategoryPageParams {
    const params: CategoryPageParams = { page: 'category', category: category };
    return params;
  }

  static allParams(): AllPageParams {
    const params: AllPageParams = { page: 'all' };
    return params;
  }

  static launchParams(functionId: string, formId: string = ''): LaunchPageParams {
    const params: LaunchPageParams = { page: 'launch', functionId: functionId, formId: formId };
    return params;
  }

  static configParams(): ConfigPageParams {
    const params: ConfigPageParams = { page: 'config' };
    return params;
  }

  static explorerParams(): ExplorerPageParams {
    const params: ExplorerPageParams = { page: 'explorer' };
    return params;
  }
}

export default PageRouter;
