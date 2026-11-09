import { describe, it, expect } from '@ohos/hypium';
import { PageRouter } from '../main/ets/pages/PageRouter';
export default function pageRouterTest() {
  describe('PageRouter', () => {
    it('category_params_carry_page_and_category', 0, () => {
      const p = PageRouter.categoryParams('出行');
      expect(p['page']).assertEqual('category');
      expect(p['category']).assertEqual('出行');
    });
    it('all_params_carry_page_all', 0, () => {
      const p = PageRouter.allParams();
      expect(p['page']).assertEqual('all');
    });
    it('config_params_carry_page_config', 0, () => {
      // I5：卡片空态「配置」入口必须能拉起 ConfigPage，不能是死入口。
      const p = PageRouter.configParams();
      expect(p['page']).assertEqual('config');
    });
    it('explorer_params_carry_page_explorer', 0, () => {
      const p = PageRouter.explorerParams();
      expect(p['page']).assertEqual('explorer');
    });
    it('launch_params_carry_function_id', 0, () => {
      // Task 5：卡片功能点击 → UIAbility 侧 LaunchDispatcher（router 是唯一可落地的传输）。
      const p = PageRouter.launchParams('fn-7');
      expect(p['page']).assertEqual('launch');
      expect(p['functionId']).assertEqual('fn-7');
    });
    it('router_action_carries_top_level_ability_name', 0, () => {
      // 真机截图验证发现：postCardAction 'router' 必须把 abilityName 放在 action
      // 顶层（华为官方 router 事件文档），只塞进 params 会静默不跳转。
      const p = PageRouter.allParams();
      const a = PageRouter.routerAction(p);
      expect(a.action).assertEqual('router');
      expect(a.abilityName).assertEqual('EntryAbility');
      expect(a.params).assertEqual(p);
    });
    it('new_want_to_page_requires_content_reload', 0, () => {
      // 真机：Ability 已在前台时，卡片 router 落到 onNewWant；若只更新 page
      // 不重新 loadContent，用户点「配置」仍看到上一次的「全量列表页」。
      expect(PageRouter.needsContentReload('all', 'config')).assertTrue();
      expect(PageRouter.needsContentReload('all', 'all')).assertFalse();
      expect(PageRouter.needsContentReload('config', 'config')).assertFalse();
    });
    it('same_category_page_with_different_category_requires_reload', 0, () => {
      // 真机复现（2026-11-09）：卡片点「支付」后再点「购物」，page 都是 category，
      // 只比较 page 不会 reload，页面仍停在「支付」。分类变化必须重载。
      expect(PageRouter.needsContentReloadForTarget('category', 'category', '支付', '购物')).assertTrue();
      expect(PageRouter.needsContentReloadForTarget('category', 'category', '支付', '支付')).assertFalse();
      expect(PageRouter.needsContentReloadForTarget('all', 'category', '', '购物')).assertTrue();
      expect(PageRouter.needsContentReloadForTarget('category', 'launch', '支付', '')).assertFalse();
    });
  });
}
